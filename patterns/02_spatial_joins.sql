-- Pattern 02: Spatial joins, distance filters, and nearest neighbors

-- Count sites in each service area. ST_Covers includes points on the boundary;
-- choose ST_Contains instead when boundary points must be excluded.
SELECT
    area.name AS service_area,
    count(site.site_id) AS site_count
FROM demo.service_areas AS area
LEFT JOIN demo.service_sites AS site
    ON ST_Covers(area.geom, site.geom)
GROUP BY area.area_id, area.name
ORDER BY area.name;

-- Find sites within 7.5 km of a search point. ST_DWithin can use the
-- geography expression index; filtering on ST_Distance would not provide the
-- same index-friendly predicate.
WITH search_point AS (
    SELECT ST_SetSRID(ST_MakePoint(-81.06, 29.26), 4326) AS geom
)
SELECT
    site.name,
    site.category,
    round((ST_Distance(site.geom::geography, search.geom::geography) / 1000.0)::numeric, 2) AS distance_km
FROM demo.service_sites AS site
CROSS JOIN search_point AS search
WHERE ST_DWithin(site.geom::geography, search.geom::geography, 7500)
ORDER BY distance_km;

-- Inspect a plan after loading representative data. The demo is intentionally
-- small, so a sequential scan can legitimately win here.
EXPLAIN (ANALYZE, BUFFERS)
SELECT site.site_id
FROM demo.service_sites AS site
WHERE ST_DWithin(
    site.geom::geography,
    ST_SetSRID(ST_MakePoint(-81.06, 29.26), 4326)::geography,
    7500
);

-- Find the nearest other site for every site. The <-> operator gives an
-- index-assisted KNN ordering; the exact geography distance is calculated
-- only for the selected neighbor.
SELECT
    site.name AS site,
    nearest.name AS nearest_site,
    round((ST_Distance(site.geom::geography, nearest.geom::geography) / 1000.0)::numeric, 2) AS distance_km
FROM demo.service_sites AS site
CROSS JOIN LATERAL (
    SELECT candidate.name, candidate.geom
    FROM demo.service_sites AS candidate
    WHERE candidate.site_id <> site.site_id
    ORDER BY site.geom <-> candidate.geom
    LIMIT 1
) AS nearest
ORDER BY site.name;

-- Assign each parcel to the service area containing its centroid. This avoids
-- double-counting parcels that cross a service-area boundary.
SELECT
    area.name AS service_area,
    count(parcel.parcel_id) AS parcel_count,
    round(sum(parcel.assessed_value), 2) AS total_assessed_value
FROM demo.service_areas AS area
LEFT JOIN demo.parcels AS parcel
    ON ST_Covers(area.geom, ST_Centroid(parcel.geom))
GROUP BY area.area_id, area.name
ORDER BY area.name;

-- Find the closest service area to an external point. For polygons, <-> orders
-- by bounding-box center distance, so calculate the exact distance for the
-- returned candidates when precision matters.
WITH search_point AS (
    SELECT ST_SetSRID(ST_MakePoint(-81.30, 29.20), 4326) AS geom
)
SELECT
    area.name,
    round((ST_Distance(area.geom::geography, search.geom::geography) / 1000.0)::numeric, 2) AS exact_distance_km
FROM demo.service_areas AS area
CROSS JOIN search_point AS search
ORDER BY search.geom <-> area.geom
LIMIT 3;
