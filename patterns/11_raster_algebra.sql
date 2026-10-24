-- Pattern 11: Raster algebra with ST_MapAlgebra
-- Compute per-pixel expressions (e.g. NDVI) across aligned rasters.
SELECT ST_MapAlgebra(a.rast, b.rast, '([rast1] - [rast2]) / ([rast1] + [rast2])') AS ndvi
FROM red a JOIN nir b ON ST_SameAlignment(a.rast, b.rast);
