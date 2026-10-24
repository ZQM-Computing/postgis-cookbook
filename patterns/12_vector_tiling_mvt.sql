-- Pattern 12: MVT vector tiles from PostGIS
-- Generate Mapbox Vector Tiles on the fly with ST_AsMVT / ST_AsMVTGeom.
SELECT ST_AsMVT(t, 'layer', 4096, 'geom') FROM (
  SELECT ST_AsMVTGeom(geom, ST_TileEnvelope(z,x,y)) AS geom, name FROM features
) t;
