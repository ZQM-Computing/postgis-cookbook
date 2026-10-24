-- Example 04: Advanced spatial indexing (SP-GiST, BRIN, partial)
-- Run with: psql -f examples/04-advanced-spatial-indexing/run.sql

CREATE INDEX IF NOT EXISTS idx_locations_geom_spgist
    ON locations USING SPGIST(geom);

CREATE INDEX IF NOT EXISTS idx_obs_geom_brin
    ON demo.sensor_observations USING BRIN(geom);

CREATE INDEX IF NOT EXISTS idx_locations_active_geom
    ON locations USING GIST(geom)
    WHERE name IS NOT NULL;

EXPLAIN (COSTS OFF)
SELECT name FROM locations
WHERE ST_DWithin(geom, ST_SetSRID(ST_MakePoint(-80.92, 29.02), 4326), 0.05);
