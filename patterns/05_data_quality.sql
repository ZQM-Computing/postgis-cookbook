-- Pattern 05: Spatial data quality
-- Run these checks in staging before a layer is promoted. Report first;
-- repair in a traceable step rather than silently overwriting the source.

-- One-row quality summary for each demo layer.
SELECT
    'service_areas' AS layer,
    count(*) AS features,
    count(*) FILTER (WHERE geom IS NULL) AS null_geometries,
    count(*) FILTER (WHERE ST_IsEmpty(geom)) AS empty_geometries,
    count(*) FILTER (WHERE NOT ST_IsValid(geom)) AS invalid_geometries,
    count(DISTINCT ST_SRID(geom)) AS distinct_srids
FROM demo.service_areas
UNION ALL
SELECT
    'service_sites',
    count(*),
    count(*) FILTER (WHERE geom IS NULL),
    count(*) FILTER (WHERE ST_IsEmpty(geom)),
    count(*) FILTER (WHERE NOT ST_IsValid(geom)),
    count(DISTINCT ST_SRID(geom))
FROM demo.service_sites
UNION ALL
SELECT
    'parcels',
    count(*),
    count(*) FILTER (WHERE geom IS NULL),
    count(*) FILTER (WHERE ST_IsEmpty(geom)),
    count(*) FILTER (WHERE NOT ST_IsValid(geom)),
    count(DISTINCT ST_SRID(geom))
FROM demo.parcels;

-- Explain invalid geometries when they exist. This query returns no rows for
-- the clean synthetic dataset.
SELECT
    parcel_id,
    (ST_IsValidDetail(geom)).reason AS invalid_reason,
    ST_AsText((ST_IsValidDetail(geom)).location) AS invalid_location
FROM demo.parcels
WHERE NOT ST_IsValid(geom);

-- Demonstrate a staged repair. ST_MakeValid can change geometry structure;
-- retain the source table and inspect row counts, geometry types, and area
-- deltas before promotion.
DROP TABLE IF EXISTS pg_temp.repaired_parcels;

CREATE TEMP TABLE repaired_parcels AS
SELECT
    parcel_id,
    ST_Multi(
        ST_CollectionExtract(ST_MakeValid(geom), 3)
    )::geometry(MultiPolygon, 4326) AS geom
FROM demo.parcels;

SELECT
    count(*) AS repaired_features,
    count(*) FILTER (WHERE NOT ST_IsValid(geom)) AS still_invalid
FROM repaired_parcels;

-- Find exact duplicate parcel geometries.
SELECT
    a.parcel_id AS parcel_a,
    b.parcel_id AS parcel_b,
    'exact geometry duplicate' AS finding
FROM demo.parcels AS a
JOIN demo.parcels AS b
    ON a.parcel_id < b.parcel_id
   AND ST_Equals(a.geom, b.geom)
ORDER BY parcel_a, parcel_b;

-- Find different parcels with the same centroid. This is a review signal,
-- not automatic proof of duplication.
SELECT
    a.parcel_id AS parcel_a,
    b.parcel_id AS parcel_b,
    'same centroid' AS finding
FROM demo.parcels AS a
JOIN demo.parcels AS b
    ON a.parcel_id < b.parcel_id
   AND ST_Equals(ST_Centroid(a.geom), ST_Centroid(b.geom))
ORDER BY parcel_a, parcel_b;

-- Inventory geometry types and dimensionality.
SELECT
    GeometryType(geom) AS geometry_type,
    ST_NDims(geom) AS dimensions,
    count(*) AS features
FROM demo.parcels
GROUP BY GeometryType(geom), ST_NDims(geom)
ORDER BY geometry_type, dimensions;
