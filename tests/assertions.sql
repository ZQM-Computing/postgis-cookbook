-- Smoke-test assertions for the synthetic dataset and pattern outputs.
-- A failed assertion raises an exception and stops the runner.

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_extension WHERE extname = 'postgis'
    ) THEN
        RAISE EXCEPTION 'PostGIS extension is not installed';
    END IF;

    IF (SELECT count(*) FROM demo.service_areas) <> 3 THEN
        RAISE EXCEPTION 'Expected 3 service areas';
    END IF;

    IF (SELECT count(*) FROM demo.service_sites) <> 9 THEN
        RAISE EXCEPTION 'Expected 9 service sites';
    END IF;

    IF (SELECT count(*) FROM demo.parcels) <> 24 THEN
        RAISE EXCEPTION 'Expected 24 parcels';
    END IF;

    IF (SELECT count(*) FROM demo.sensor_observations) <> 27 THEN
        RAISE EXCEPTION 'Expected 27 sensor observations';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM demo.service_areas
        WHERE geom IS NULL
           OR ST_SRID(geom) <> 4326
           OR ST_IsEmpty(geom)
           OR NOT ST_IsValid(geom)
    ) THEN
        RAISE EXCEPTION 'Service-area data failed SRID, emptiness, or validity checks';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM demo.parcels
        WHERE geom IS NULL
           OR ST_SRID(geom) <> 4326
           OR ST_IsEmpty(geom)
           OR NOT ST_IsValid(geom)
    ) THEN
        RAISE EXCEPTION 'Parcel data failed SRID, emptiness, or validity checks';
    END IF;

    IF (
        SELECT count(DISTINCT indexname)
        FROM pg_indexes
        WHERE schemaname = 'demo'
          AND indexname IN (
              'service_areas_geom_gist',
              'service_sites_geom_gist',
              'service_sites_geography_gist',
              'parcels_geom_gist',
              'sensor_observations_observed_at_brin'
          )
    ) <> 5 THEN
        RAISE EXCEPTION 'One or more core pattern indexes are missing';
    END IF;

    -- An index name in pg_indexes is not sufficient: invalid indexes can
    -- remain after interrupted concurrent builds or failed migrations.
    IF EXISTS (
        SELECT 1
        FROM pg_index AS i
        JOIN pg_class AS idx ON idx.oid = i.indexrelid
        JOIN pg_namespace AS ns ON ns.oid = idx.relnamespace
        WHERE ns.nspname = 'demo'
          AND idx.relname IN (
              'service_areas_geom_gist',
              'service_sites_geom_gist',
              'service_sites_geography_gist',
              'parcels_geom_gist',
              'sensor_observations_observed_at_brin'
          )
          AND (NOT i.indisvalid OR NOT i.indisready)
    ) THEN
        RAISE EXCEPTION 'A required core pattern index exists but is not valid and ready';
    END IF;

    -- The index-assisted bounding-box prefilter must not change the exact
    -- ST_Intersects result set for this fixed query envelope.
    IF EXISTS (
        (
            SELECT area_id
            FROM demo.service_areas
            WHERE ST_Intersects(
                geom,
                ST_MakeEnvelope(-81.15, 29.05, -81.00, 29.30, 4326)
            )
            EXCEPT
            SELECT area_id
            FROM demo.service_areas
            WHERE geom && ST_MakeEnvelope(-81.15, 29.05, -81.00, 29.30, 4326)
              AND ST_Intersects(
                  geom,
                  ST_MakeEnvelope(-81.15, 29.05, -81.00, 29.30, 4326)
              )
        )
        UNION ALL
        (
            SELECT area_id
            FROM demo.service_areas
            WHERE geom && ST_MakeEnvelope(-81.15, 29.05, -81.00, 29.30, 4326)
              AND ST_Intersects(
                  geom,
                  ST_MakeEnvelope(-81.15, 29.05, -81.00, 29.30, 4326)
              )
            EXCEPT
            SELECT area_id
            FROM demo.service_areas
            WHERE ST_Intersects(
                geom,
                ST_MakeEnvelope(-81.15, 29.05, -81.00, 29.30, 4326)
            )
        )
    ) THEN
        RAISE EXCEPTION 'Bounding-box prefilter changed exact intersection results';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM demo.service_sites
        WHERE geom IS NULL
           OR ST_SRID(geom) <> 4326
           OR GeometryType(geom) <> 'POINT'
           OR ST_IsEmpty(geom)
           OR NOT ST_IsValid(geom)
    ) THEN
        RAISE EXCEPTION 'Service-site geometry contract failed';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM demo.sensor_observations AS observation
        JOIN demo.service_sites AS site USING (site_id)
        WHERE observation.geom IS NULL
           OR ST_SRID(observation.geom) <> 4326
           OR ST_IsEmpty(observation.geom)
           OR NOT ST_IsValid(observation.geom)
           OR NOT ST_Equals(observation.geom, site.geom)
    ) THEN
        RAISE EXCEPTION 'Observation geometry must be valid and match its source site';
    END IF;

    IF EXISTS (
        SELECT site_id
        FROM demo.sensor_observations
        GROUP BY site_id
        HAVING count(*) <> 3
    ) OR (
        SELECT count(DISTINCT site_id)
        FROM demo.sensor_observations
    ) <> (SELECT count(*) FROM demo.service_sites) THEN
        RAISE EXCEPTION 'Expected exactly three observations for every service site';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM demo.sensor_observations
        WHERE observed_at < TIMESTAMPTZ '2026-01-01 00:00:00+00'
           OR observed_at >= TIMESTAMPTZ '2027-01-01 00:00:00+00'
    ) THEN
        RAISE EXCEPTION 'Observation timestamps are outside the 2026 demo partition window';
    END IF;

    IF (SELECT count(*) FROM demo.service_area_measurements) <> 3 THEN
        RAISE EXCEPTION 'Expected measurements for 3 service areas';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM demo.service_area_measurements
        WHERE area_acres_geography <= 0
           OR area_acres_florida_state_plane <= 0
    ) THEN
        RAISE EXCEPTION 'Service-area measurements must be positive';
    END IF;

    IF (
        SELECT count(*)
        FROM demo.sensor_observations_partitioned
    ) <> (
        SELECT count(*)
        FROM demo.sensor_observations
    ) THEN
        RAISE EXCEPTION 'Partitioned observation count does not match the source table';
    END IF;

    -- Counts alone can hide dropped or duplicated values; compare the
    -- business columns in both directions, excluding generated identity IDs.
    IF EXISTS (
        (
            SELECT site_id, observed_at, reading_value, ST_AsEWKB(geom)
            FROM demo.sensor_observations
            EXCEPT
            SELECT site_id, observed_at, reading_value, ST_AsEWKB(geom)
            FROM demo.sensor_observations_partitioned
        )
        UNION ALL
        (
            SELECT site_id, observed_at, reading_value, ST_AsEWKB(geom)
            FROM demo.sensor_observations_partitioned
            EXCEPT
            SELECT site_id, observed_at, reading_value, ST_AsEWKB(geom)
            FROM demo.sensor_observations
        )
    ) THEN
        RAISE EXCEPTION 'Partitioned observations differ from source values';
    END IF;
END
$$;

SELECT 'postgis-cookbook smoke test passed' AS result;
