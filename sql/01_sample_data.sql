-- Deterministic synthetic data around Volusia County, Florida.
-- These features are illustrative only and do not describe real parcels,
-- facilities, infrastructure, or people.

TRUNCATE TABLE
    demo.sensor_observations,
    demo.parcels,
    demo.service_sites,
    demo.service_areas
RESTART IDENTITY CASCADE;

INSERT INTO demo.service_areas (area_id, name, geom)
VALUES
    (
        1,
        'North service area',
        ST_Multi(ST_MakeEnvelope(-81.20, 29.18, -80.95, 29.38, 4326))
    ),
    (
        2,
        'Central service area',
        ST_Multi(ST_MakeEnvelope(-81.20, 28.98, -80.95, 29.18, 4326))
    ),
    (
        3,
        'Coastal service area',
        ST_Multi(ST_MakeEnvelope(-80.95, 28.98, -80.72, 29.38, 4326))
    );

INSERT INTO demo.service_sites (site_id, name, category, opened_on, geom)
VALUES
    (1, 'North depot', 'operations', DATE '2018-04-12', ST_SetSRID(ST_MakePoint(-81.10, 29.28), 4326)),
    (2, 'North library', 'civic', DATE '2015-09-01', ST_SetSRID(ST_MakePoint(-81.02, 29.22), 4326)),
    (3, 'Central depot', 'operations', DATE '2020-01-20', ST_SetSRID(ST_MakePoint(-81.10, 29.08), 4326)),
    (4, 'Central clinic', 'health', DATE '2019-06-15', ST_SetSRID(ST_MakePoint(-81.00, 29.05), 4326)),
    (5, 'Coastal depot', 'operations', DATE '2021-03-08', ST_SetSRID(ST_MakePoint(-80.85, 29.28), 4326)),
    (6, 'Coastal library', 'civic', DATE '2016-11-03', ST_SetSRID(ST_MakePoint(-80.80, 29.10), 4326)),
    (7, 'Coastal sensor hub', 'utility', DATE '2022-08-19', ST_SetSRID(ST_MakePoint(-80.90, 29.18), 4326)),
    (8, 'North sensor hub', 'utility', DATE '2023-02-10', ST_SetSRID(ST_MakePoint(-81.16, 29.33), 4326)),
    (9, 'Coastal clinic', 'health', DATE '2017-05-25', ST_SetSRID(ST_MakePoint(-80.76, 29.33), 4326));

INSERT INTO demo.parcels (parcel_id, land_use, assessed_value, geom)
SELECT
    'SYNTH-' || lpad(grid_number::text, 3, '0'),
    (ARRAY['residential', 'commercial', 'conservation', 'civic'])[1 + grid_number % 4],
    75000 + grid_number * 12500,
    ST_MakeEnvelope(
        -81.18 + (grid_number % 6) * 0.055,
        29.01 + (grid_number / 6) * 0.075,
        -81.14 + (grid_number % 6) * 0.055,
        29.06 + (grid_number / 6) * 0.075,
        4326
    )
FROM generate_series(0, 23) AS grid_number;

INSERT INTO demo.sensor_observations (site_id, observed_at, reading_value, geom)
SELECT
    site.site_id,
    TIMESTAMPTZ '2026-01-15 12:00:00+00' + make_interval(days => sample_number * 14),
    18.5 + site.site_id + sample_number,
    site.geom
FROM demo.service_sites AS site
CROSS JOIN generate_series(0, 2) AS sample_number
ORDER BY site.site_id, sample_number;

SELECT 'service_areas' AS table_name, count(*) AS row_count FROM demo.service_areas
UNION ALL
SELECT 'service_sites', count(*) FROM demo.service_sites
UNION ALL
SELECT 'parcels', count(*) FROM demo.parcels
UNION ALL
SELECT 'sensor_observations', count(*) FROM demo.sensor_observations;
