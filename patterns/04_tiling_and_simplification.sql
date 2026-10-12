-- Pattern 04: Tiling, subdivision, and simplification
-- Prepare geometry for delivery without degrading the stored source geometry.

-- Break complex polygons into smaller stored bounding boxes for repeated
-- intersection and tile-generation work. ST_Subdivide returns multiple rows;
-- retain the source identifier so results can be grouped back to the feature.
DROP TABLE IF EXISTS pg_temp.subdivided_service_areas;

CREATE TEMP TABLE subdivided_service_areas AS
SELECT
    area_id,
    name,
    ST_Subdivide(geom, 32) AS geom
FROM demo.service_areas;

SELECT
    (SELECT count(*) FROM demo.service_areas) AS source_polygons,
    count(*) AS subdivided_parts
FROM subdivided_service_areas;

-- Simplify in a projected CRS where the tolerance has linear units.
-- Here the tolerance is 25 US survey feet in EPSG:2236. The output is
-- transformed back to EPSG:4326 for comparison and delivery.
SELECT
    parcel_id,
    round((ST_Area(ST_Transform(geom, 2236)) / 43560.0)::numeric, 3) AS source_area_acres,
    round((
        ST_Area(
            ST_SimplifyPreserveTopology(ST_Transform(geom, 2236), 25.0)
        ) / 43560.0
    )::numeric, 3) AS simplified_area_acres,
    ST_NPoints(geom) AS source_points,
    ST_NPoints(
        ST_Transform(
            ST_SimplifyPreserveTopology(ST_Transform(geom, 2236), 25.0),
            4326
        )
    ) AS simplified_points
FROM demo.parcels
ORDER BY parcel_id
LIMIT 5;

-- Generate a Mapbox Vector Tile payload for one EPSG:3857 tile and report its
-- size. Tile 12/1126/1700 intersects the sample extent. In an application, bind
-- the tile coordinates as parameters and return the bytea payload directly.
WITH tile AS (
    SELECT ST_TileEnvelope(12, 1126, 1700) AS geom
),
tile_rows AS (
    SELECT
        area.name,
        ST_AsMVTGeom(
            ST_Transform(area.geom, 3857),
            tile.geom,
            4096,
            64,
            true
        ) AS geom
    FROM demo.service_areas AS area
    CROSS JOIN tile
    WHERE ST_Intersects(ST_Transform(area.geom, 3857), tile.geom)
)
SELECT
    octet_length(ST_AsMVT(tile_rows, 'service_areas', 4096, 'geom')) AS mvt_bytes
FROM tile_rows;

-- Use GeoHash cells for coarse grouping, exploratory clustering, or choosing
-- a processing partition. A GeoHash is an index and grouping aid, not a
-- substitute for an exact spatial predicate.
SELECT
    ST_GeoHash(geom, 6) AS geohash_cell,
    count(*) AS site_count,
    string_agg(name, ', ' ORDER BY name) AS sites
FROM demo.service_sites
GROUP BY ST_GeoHash(geom, 6)
ORDER BY geohash_cell;
