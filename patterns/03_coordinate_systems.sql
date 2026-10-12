-- Pattern 03: Coordinate systems and measurement
-- Store in EPSG:4326, measure with geography or a suitable projected CRS,
-- and transform for display only at the delivery boundary.

-- Inventory the geometry columns and their enforced SRIDs.
SELECT
    f_table_name,
    f_geometry_column,
    type,
    srid
FROM public.geometry_columns
WHERE f_table_schema = 'demo'
ORDER BY f_table_name, f_geometry_column;

-- Compare measurement methods for the service areas.
-- EPSG:2236 is Florida State Plane East in US survey feet, so square feet
-- convert to acres by dividing by 43,560.
CREATE OR REPLACE VIEW demo.service_area_measurements AS
SELECT
    area_id,
    name,
    ST_Area(geom) AS area_square_degrees_not_for_reporting,
    ST_Area(geom::geography) / 4046.8564224 AS area_acres_geography,
    ST_Area(ST_Transform(geom, 2236)) / 43560.0 AS area_acres_florida_state_plane,
    ST_Perimeter(geom::geography) / 1609.344 AS perimeter_miles_geography
FROM demo.service_areas;

SELECT *
FROM demo.service_area_measurements
ORDER BY name;

-- Calculate site-to-site distance in kilometers and miles using geography.
SELECT
    a.name AS from_site,
    b.name AS to_site,
    round((ST_Distance(a.geom::geography, b.geom::geography) / 1000.0)::numeric, 2) AS distance_km,
    round((ST_Distance(a.geom::geography, b.geom::geography) / 1609.344)::numeric, 2) AS distance_miles
FROM demo.service_sites AS a
JOIN demo.service_sites AS b
    ON a.site_id = 1
   AND b.site_id = 5;

-- Build a 500-meter operational buffer without pretending that degrees are
-- linear units. The buffer is created in geography, then returned as geometry
-- for composition with the stored layers.
CREATE OR REPLACE VIEW demo.service_site_buffers AS
SELECT
    site_id,
    name,
    ST_Buffer(geom::geography, 500)::geometry AS buffer_500m
FROM demo.service_sites;

SELECT
    name,
    round((ST_Area(buffer_500m::geography) / 4046.8564224)::numeric, 2) AS buffer_area_acres
FROM demo.service_site_buffers
ORDER BY name;

-- Transform coordinates at the display boundary. EPSG:3857 is suitable for
-- web-map placement in this example, not for the measurements above.
SELECT
    name,
    round(ST_X(ST_Transform(geom, 3857))::numeric, 2) AS web_mercator_x,
    round(ST_Y(ST_Transform(geom, 3857))::numeric, 2) AS web_mercator_y,
    ST_AsGeoJSON(geom) AS geojson
FROM demo.service_sites
ORDER BY site_id
LIMIT 3;

-- Inspect the projected CRS definition used for local measurement.
SELECT
    srid,
    left(proj4text, 120) AS proj4_preview
FROM public.spatial_ref_sys
WHERE srid = 2236;
