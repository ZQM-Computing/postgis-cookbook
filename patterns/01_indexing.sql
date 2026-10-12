-- Pattern 01: Indexing
-- Start with GiST for geometry. Add expression, partial, and BRIN indexes only
-- when the workload gives them a job to do.

-- Core spatial indexes.
CREATE INDEX IF NOT EXISTS service_areas_geom_gist
    ON demo.service_areas USING gist (geom);

CREATE INDEX IF NOT EXISTS service_sites_geom_gist
    ON demo.service_sites USING gist (geom);

CREATE INDEX IF NOT EXISTS parcels_geom_gist
    ON demo.parcels USING gist (geom);

CREATE INDEX IF NOT EXISTS sensor_observations_geom_gist
    ON demo.sensor_observations USING gist (geom);

-- Meter-based ST_DWithin queries against longitude/latitude geometry can use
-- this expression index when the query casts the column to geography in the
-- same way.
CREATE INDEX IF NOT EXISTS service_sites_geography_gist
    ON demo.service_sites USING gist ((geom::geography));

CREATE INDEX IF NOT EXISTS parcels_geography_gist
    ON demo.parcels USING gist ((geom::geography));

-- Spatial predicates rarely travel alone. Index the selective attributes that
-- applications filter on at the same time.
CREATE INDEX IF NOT EXISTS service_sites_category_idx
    ON demo.service_sites (category);

CREATE INDEX IF NOT EXISTS parcels_land_use_idx
    ON demo.parcels (land_use);

CREATE INDEX IF NOT EXISTS sensor_observations_site_idx
    ON demo.sensor_observations (site_id);

-- A partial index is useful when a stable subset is queried constantly.
-- It is smaller than a second full index, but it only helps queries whose
-- predicate implies the index predicate.
CREATE INDEX IF NOT EXISTS parcels_conservation_geom_gist
    ON demo.parcels USING gist (geom)
    WHERE land_use = 'conservation';

-- BRIN is worth benchmarking on very large append-mostly tables when physical
-- row order correlates with observed_at. On this 27-row demo it is present to
-- show the shape, not to demonstrate a measurable win.
CREATE INDEX IF NOT EXISTS sensor_observations_observed_at_brin
    ON demo.sensor_observations USING brin (observed_at);

-- Refresh planner statistics after index creation and bulk data changes.
ANALYZE demo.service_areas;
ANALYZE demo.service_sites;
ANALYZE demo.parcels;
ANALYZE demo.sensor_observations;

-- Inventory the result.
SELECT
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'demo'
ORDER BY tablename, indexname;
