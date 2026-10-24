-- Pattern 09: Raster tiling and overview
-- Tile large rasters into manageable chunks and build overviews for fast
-- display. ST_Tile + ST_Resize for pyramid levels.
SELECT ST_Tile(rast, 256, 256) AS tile FROM raster_table;
