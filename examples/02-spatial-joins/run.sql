-- Example 02: Spatial joins
-- Run with: psql -f examples/02-spatial-joins/run.sql

CREATE TABLE IF NOT EXISTS zones (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    geom GEOMETRY(POLYGON, 4326)
);

INSERT INTO zones (name, geom) VALUES
('Downtown', ST_SetSRID(ST_MakePolygon(ST_GeomFromText('LINESTRING(-80.95 29.05, -80.90 29.05, -80.90 29.00, -80.95 29.00, -80.95 29.05)')), 4326));

-- Find all locations within Downtown
SELECT l.name
FROM locations l
JOIN zones z ON ST_Within(l.geom, z.geom)
WHERE z.name = 'Downtown';
