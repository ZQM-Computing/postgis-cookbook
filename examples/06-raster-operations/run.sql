-- Example 06: Raster operations
-- Run with: psql -f examples/06-raster-operations/run.sql

SELECT ST_Value(rast, 1, ST_SetSRID(ST_MakePoint(-80.92, 29.02), 4326)) AS pixel_value
FROM raster_table
LIMIT 1;
