-- Example 01: Spatial indexing with GiST
-- Run with: psql -f examples/01-spatial-indexing/run.sql

CREATE TABLE IF NOT EXISTS locations (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    geom GEOMETRY(POINT, 4326)
);

INSERT INTO locations (name, geom) VALUES
('Shop A', ST_SetSRID(ST_MakePoint(-80.93, 29.02), 4326)),
('Shop B', ST_SetSRID(ST_MakePoint(-80.92, 29.03), 4326)),
('Shop C', ST_SetSRID(ST_MakePoint(-80.91, 29.01), 4326));

CREATE INDEX idx_locations_geom ON locations USING GIST(geom);

-- Nearest neighbor query
SELECT name, ST_Distance(geom, ST_SetSRID(ST_MakePoint(-80.92, 29.02), 4326)) AS dist
FROM locations
ORDER BY geom <-> ST_SetSRID(ST_MakePoint(-80.92, 29.02), 4326)
LIMIT 3;
