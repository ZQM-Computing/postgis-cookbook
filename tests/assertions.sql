-- Smoke-test assertions for the synthetic dataset and pattern outputs.
-- A failed assertion raises an exception and stops the runner.

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_extension WHERE extname = 'postgis'
    ) THEN
        RAISE EXCEPTION 'PostGIS extension is not installed';
    END IF;

    -- Check that the schema still enforces the core relational contract,
    -- rather than merely passing because today's fixture happens to be clean.
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'demo.service_sites'::regclass
          AND contype = 'p'
    ) THEN
        RAISE EXCEPTION 'service_sites primary key constraint is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'demo.sensor_observations'::regclass
          AND conname = 'sensor_observations_site_id_fkey'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION 'sensor_observations site foreign key is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_attribute
        WHERE attrelid = 'demo.service_sites'::regclass
          AND attname = 'geom'
          AND attnotnull
          AND NOT attisdropped
    ) THEN
        RAISE EXCEPTION 'service_sites.geom must remain NOT NULL';
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
              'sensor_observations_geom_gist',
              'service_sites_geography_gist',
              'parcels_geom_gist',
              'parcels_geography_gist',
              'service_sites_category_idx',
              'parcels_land_use_idx',
              'sensor_observations_site_idx',
              'parcels_conservation_geom_gist',
              'sensor_observations_observed_at_brin'
          )
    ) <> 11 THEN
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
              'sensor_observations_geom_gist',
              'service_sites_geography_gist',
              'parcels_geom_gist',
              'parcels_geography_gist',
              'service_sites_category_idx',
              'parcels_land_use_idx',
              'sensor_observations_site_idx',
              'parcels_conservation_geom_gist',
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


-- Negative-path regression tests: prove the demo schema rejects representative
-- invalid writes. Each expected exception rolls back its sub-block, so these
-- probes leave the fixture unchanged.
DO $$
DECLARE
    rejected boolean;
BEGIN
    rejected := false;
    BEGIN
        INSERT INTO demo.service_sites (site_id, name, category, opened_on, geom)
        VALUES (
            1,
            'duplicate primary-key probe',
            'test',
            DATE '2026-01-01',
            ST_SetSRID(ST_MakePoint(-81.0, 29.0), 4326)
        );
    EXCEPTION WHEN unique_violation THEN
        rejected := true;
    END;
    IF NOT rejected THEN
        RAISE EXCEPTION 'Duplicate service-site primary key was accepted';
    END IF;

    rejected := false;
    BEGIN
        INSERT INTO demo.service_sites (site_id, name, category, opened_on, geom)
        VALUES (
            1001,
            'null geometry probe',
            'test',
            DATE '2026-01-01',
            NULL
        );
    EXCEPTION WHEN not_null_violation THEN
        rejected := true;
    END;
    IF NOT rejected THEN
        RAISE EXCEPTION 'Null service-site geometry was accepted';
    END IF;

    rejected := false;
    BEGIN
        INSERT INTO demo.sensor_observations (site_id, observed_at, reading_value, geom)
        VALUES (
            2147483000,
            TIMESTAMPTZ '2026-06-01 12:00:00+00',
            1.0,
            ST_SetSRID(ST_MakePoint(-81.0, 29.0), 4326)
        );
    EXCEPTION WHEN foreign_key_violation THEN
        rejected := true;
    END;
    IF NOT rejected THEN
        RAISE EXCEPTION 'Observation referencing a nonexistent site was accepted';
    END IF;

    rejected := false;
    BEGIN
        INSERT INTO demo.sensor_observations_partitioned
            (site_id, observed_at, reading_value, geom)
        VALUES (
            1,
            TIMESTAMPTZ '2025-12-31 23:59:59+00',
            1.0,
            ST_SetSRID(ST_MakePoint(-81.0, 29.0), 4326)
        );
    EXCEPTION WHEN check_violation THEN
        rejected := true;
    END;
    IF NOT rejected THEN
        RAISE EXCEPTION 'Observation outside configured partitions was accepted';
    END IF;

    -- The upper bound is exclusive: 2027-01-01 must also fail without a
    -- 2027 partition. This catches accidental widening of the demo contract.
    rejected := false;
    BEGIN
        INSERT INTO demo.sensor_observations_partitioned
            (site_id, observed_at, reading_value, geom)
        VALUES (
            1,
            TIMESTAMPTZ '2027-01-01 00:00:00+00',
            1.0,
            ST_SetSRID(ST_MakePoint(-81.0, 29.0), 4326)
        );
    EXCEPTION WHEN check_violation THEN
        rejected := true;
    END;
    IF NOT rejected THEN
        RAISE EXCEPTION 'Observation at exclusive upper partition boundary was accepted';
    END IF;

    -- Geometry typmods must reject both a wrong SRID and a wrong geometry
    -- subtype. These probes accept only the expected data-contract error
    -- classes, not arbitrary SQL failures.
    rejected := false;
    BEGIN
        INSERT INTO demo.service_sites (site_id, name, category, opened_on, geom)
        VALUES (
            1002,
            'wrong SRID probe',
            'test',
            DATE '2026-01-01',
            ST_SetSRID(ST_MakePoint(-81.0, 29.0), 3857)
        );
    EXCEPTION WHEN check_violation OR invalid_parameter_value THEN
        rejected := true;
    END;
    IF NOT rejected THEN
        RAISE EXCEPTION 'Service-site geometry with wrong SRID was accepted';
    END IF;

    rejected := false;
    BEGIN
        INSERT INTO demo.service_sites (site_id, name, category, opened_on, geom)
        VALUES (
            1003,
            'wrong geometry type probe',
            'test',
            DATE '2026-01-01',
            ST_SetSRID(ST_MakeLine(
                ST_MakePoint(-81.0, 29.0),
                ST_MakePoint(-81.01, 29.01)
            ), 4326)
        );
    EXCEPTION WHEN check_violation OR invalid_parameter_value THEN
        rejected := true;
    END;
    IF NOT rejected THEN
        RAISE EXCEPTION 'Non-Point geometry was accepted by service_sites.geom';
    END IF;

    IF (SELECT count(*) FROM demo.service_sites) <> 9
       OR (SELECT count(*) FROM demo.sensor_observations) <> 27
       OR (SELECT count(*) FROM demo.sensor_observations_partitioned) <> 27 THEN
        RAISE EXCEPTION 'Negative-path tests changed the demo fixture';
    END IF;
END
$$;

SELECT 'postgis-cookbook negative-path regression tests passed' AS result;


-- The row-level-security example must leave the shared fixture and role catalog
-- clean for subsequent patterns and repeatable CI runs.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_class AS relation
        JOIN pg_namespace AS namespace ON namespace.oid = relation.relnamespace
        WHERE namespace.nspname = 'demo'
          AND relation.relname IN ('service_sites', 'parcels')
          AND (relation.relrowsecurity OR relation.relforcerowsecurity)
    ) THEN
        RAISE EXCEPTION 'Pattern 07 left row-level security enabled on a shared fixture table';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_policies
        WHERE schemaname = 'demo'
          AND policyname LIKE 'postgis_cb_%'
    ) THEN
        RAISE EXCEPTION 'Pattern 07 left a demo row-level security policy behind';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname IN (
            'postgis_cb_north_ops',
            'postgis_cb_coastal_ops',
            'postgis_cb_read_all_geo'
        )
    ) THEN
        RAISE EXCEPTION 'Pattern 07 left a temporary demo role behind';
    END IF;
END
$$;

SELECT 'postgis-cookbook RLS cleanup assertions passed' AS result;

-- Rank 1 negative and positive QA for SYNTHETIC environmental exhibit data.
-- Desktop/database only: not wetland delineation, jurisdictional determination,
-- Phase I ESA, survey, professional certification, or permit approval.
-- Each result must retain source + retrieval date and uncertainty flags.
DO $rank1_test$
DECLARE
    rejected boolean;
BEGIN
    IF (SELECT count(*) FROM demo.environmental_exhibit_summary) <> 6 THEN
        RAISE EXCEPTION 'Rank 1 expected 3 parcels x 2 sources';
    END IF;
    IF (SELECT count(*) FROM demo.environmental_source_register) <> 2 THEN
        RAISE EXCEPTION 'Rank 1 source register missing records';
    END IF;
    IF EXISTS (
        SELECT 1 FROM demo.environmental_exhibit_summary
        WHERE source_id IS NULL OR dataset_name IS NULL
           OR publisher IS NULL OR retrieved_on IS NULL OR source_url IS NULL
           OR btrim(known_limitations) = ''
           OR measurement_srid <> 2236
           OR linear_units <> 'US survey feet'
           OR parcel_acres <= 0 OR known_overlap_acres < 0
           OR known_overlap_acres > parcel_acres
           OR coverage_pct < 0 OR coverage_pct > 100.01
           OR overlap_pct < 0 OR overlap_pct > 100.01
           OR (data_gap_flag AND screening_status NOT IN
               ('no_source_coverage','partial_source_coverage'))
    ) THEN
        RAISE EXCEPTION 'Rank 1 output QA, source, CRS or uncertainty contract failed';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM demo.environmental_exhibit_summary
        WHERE parcel_id = 'SYNTH-000' AND constraint_type = 'wetland_indicator'
          AND has_mapped_indicator AND NOT data_gap_flag AND known_overlap_acres > 0
    ) THEN
        RAISE EXCEPTION 'Rank 1 synthetic wetland intersection missing';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM demo.environmental_exhibit_summary
        WHERE parcel_id = 'SYNTH-001' AND constraint_type = 'flood_indicator'
          AND has_mapped_indicator AND NOT data_gap_flag AND known_overlap_acres > 0
    ) THEN
        RAISE EXCEPTION 'Rank 1 synthetic flood intersection missing';
    END IF;
    IF (SELECT count(*) FROM demo.environmental_exhibit_summary
        WHERE constraint_type = 'wetland_indicator'
          AND screening_status = 'no_source_coverage'
          AND data_gap_flag AND NOT has_mapped_indicator) <> 2 THEN
        RAISE EXCEPTION 'Rank 1 absent wetland coverage incorrectly treated as negative';
    END IF;
    IF (SELECT count(*) FROM demo.environmental_exhibit_summary
        WHERE constraint_type = 'flood_indicator'
          AND screening_status = 'no_mapped_intersection'
          AND NOT data_gap_flag AND NOT has_mapped_indicator) <> 2 THEN
        RAISE EXCEPTION 'Rank 1 flood no-mapped-hit status or coverage incorrect';
    END IF;

    -- The database contract must reject incomplete source registration.
    rejected := false;
    BEGIN
        UPDATE demo.environmental_source_register
        SET source_url = 'http://not-https.invalid'
        WHERE source_id = 'SYN-WET';
    EXCEPTION WHEN check_violation THEN
        rejected := true;
    END;
    IF NOT rejected THEN
        RAISE EXCEPTION 'Rank 1 invalid source registration accepted';
    END IF;

    -- A wrong SRID must not be accepted as geometrically valid display data.
    rejected := false;
    BEGIN
        INSERT INTO demo.wetland_indicators (indicator_id, source_id, geom)
        VALUES ('BAD-SRID', 'SYN-WET',
                ST_Multi(ST_MakeEnvelope(0, 0, 5, 5, 3857)));
    EXCEPTION WHEN check_violation OR invalid_parameter_value THEN
        rejected := true;
    END;
    IF NOT rejected THEN
        RAISE EXCEPTION 'Rank 1 wrong SRID was accepted';
    END IF;
    IF (SELECT count(*) FROM demo.wetland_indicators) <> 1
       OR (SELECT count(*) FROM demo.flood_zones) <> 1 THEN
        RAISE EXCEPTION 'Rank 1 negative QA changed fixture rows';
    END IF;
END
$rank1_test$;

SELECT 'Rank 1 synthetic exhibit QA and provenance assertions passed' AS result;
