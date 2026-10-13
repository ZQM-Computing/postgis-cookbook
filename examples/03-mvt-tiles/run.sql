-- Example 03: Mapbox Vector Tiles with ST_AsMVT
-- Run with: psql -f examples/03-mvt-tiles/run.sql

SELECT ST_AsMVT(q, 'locations', 4096, 'geom') AS mvt
FROM (
    SELECT
        l.id,
        l.name,
        ST_AsMVTGeom(l.geom, ST_TileEnvelope(10, 512, 512), 4096, 256, true) AS geom
    FROM locations l
    WHERE l.geom && ST_TileEnvelope(10, 512, 512)
) q;
