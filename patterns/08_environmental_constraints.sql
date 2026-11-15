-- Rank 1 pattern: Environmental constraints screening & exhibit preparation.
-- Desktop / database analysis only. SYNTHETIC geometries and metadata only.
-- Does NOT constitute a field wetland delineation, jurisdictional determination,
-- Phase I environmental site assessment (ESA), survey, professional certification,
-- engineering opinion, or permit approval.
-- Verify every real indicator with qualified professionals and current sources.
-- This demonstrates technical workflow and QA, NOT completed client work.
--
-- Scope: three existing demo parcels; indicator layers, explicit SOURCE COVERAGE,
-- source+retrieval date register, area in EPSG:2236 (Florida State Plane East,
-- US survey feet), and observable unknown-coverage/uncertainty flags.
-- EPSG:2236 values are SQUARE FEET, not square metres. One acre = 43,560 ft².
-- Do not treat "no_mapped_intersection" as an absence of regulated features.
-- Original data is stored in 4326; ST_Transform performs the actual conversion.
BEGIN;

CREATE TABLE IF NOT EXISTS demo.environmental_source_register (
    source_id text PRIMARY KEY,
    constraint_type text NOT NULL UNIQUE CHECK
        (constraint_type IN ('wetland_indicator', 'flood_indicator')),
    dataset_name text NOT NULL CHECK (length(btrim(dataset_name)) > 0),
    publisher text NOT NULL CHECK (length(btrim(publisher)) > 0),
    retrieved_on date NOT NULL,
    dataset_version text NOT NULL CHECK (length(btrim(dataset_version)) > 0),
    source_url text NOT NULL CHECK (source_url ~ '^https://'),
    known_limitations text NOT NULL CHECK (length(btrim(known_limitations)) > 0)
);
CREATE TABLE IF NOT EXISTS demo.environmental_source_coverage (
    coverage_id text PRIMARY KEY,
    source_id text NOT NULL REFERENCES demo.environmental_source_register(source_id),
    geom geometry(MultiPolygon, 4326) NOT NULL
        CHECK (NOT ST_IsEmpty(geom) AND ST_IsValid(geom))
);
CREATE TABLE IF NOT EXISTS demo.wetland_indicators (
    indicator_id text PRIMARY KEY,
    source_id text NOT NULL REFERENCES demo.environmental_source_register(source_id),
    geom geometry(MultiPolygon, 4326) NOT NULL
        CHECK (NOT ST_IsEmpty(geom) AND ST_IsValid(geom))
);
CREATE TABLE IF NOT EXISTS demo.flood_zones (
    indicator_id text PRIMARY KEY,
    source_id text NOT NULL REFERENCES demo.environmental_source_register(source_id),
    geom geometry(MultiPolygon, 4326) NOT NULL
        CHECK (NOT ST_IsEmpty(geom) AND ST_IsValid(geom))
);
COMMENT ON TABLE demo.environmental_source_register IS
    'Synthetic source/date registry, not authentic FEMA/NWI data.';
COMMENT ON TABLE demo.environmental_source_coverage IS
    'Synthetic evaluated footprint: absent coverage is NOT a negative finding.';
COMMENT ON TABLE demo.wetland_indicators IS
    'Synthetic inventory-style mapped wetland indicators; no legal boundary.';
COMMENT ON TABLE demo.flood_zones IS
    'Synthetic flood-hazard-style mapped indicators; NOT a FEMA determination.';

TRUNCATE demo.wetland_indicators, demo.flood_zones,
         demo.environmental_source_coverage, demo.environmental_source_register;

INSERT INTO demo.environmental_source_register
    (source_id, constraint_type, dataset_name, publisher, retrieved_on,
     dataset_version, source_url, known_limitations)
VALUES
    ('SYN-WET', 'wetland_indicator', 'Synthetic inventory-style wetlands',
     'ZQM synthetic demonstration', DATE '2026-11-14', 'fixture-v1',
     'https://example.org/synthetic/wetlands',
     'Artificial wetland indicators; coverage excludes two demo parcels; not field verified.'),
    ('SYN-FLD', 'flood_indicator', 'Synthetic flood-hazard-style polygons',
     'ZQM synthetic demonstration', DATE '2026-11-14', 'fixture-v1',
     'https://example.org/synthetic/flood',
     'Artificial flood indicator; covers only three demo parcels; not FEMA data.');

-- COVERAGE is a separate data contract from indicator polygons.
-- One source covers only SYNTH-000. Flood source covers all three parcels.
INSERT INTO demo.environmental_source_coverage (coverage_id, source_id, geom)
SELECT 'SYN-COV-WET', 'SYN-WET', ST_Multi(p.geom)
FROM demo.parcels AS p WHERE p.parcel_id = 'SYNTH-000';

INSERT INTO demo.environmental_source_coverage (coverage_id, source_id, geom)
SELECT 'SYN-COV-FLD-' || p.parcel_id, 'SYN-FLD', ST_Multi(p.geom)
FROM demo.parcels AS p
WHERE p.parcel_id IN ('SYNTH-000', 'SYNTH-001', 'SYNTH-002');

-- Produce synthetic indicator features by clipping a projected parcel footprint
-- to its western half, then transform to the demo storage CRS. No real maps.
INSERT INTO demo.wetland_indicators (indicator_id, source_id, geom)
SELECT 'SYN-WET-01', 'SYN-WET', ST_Multi(ST_Transform(
    ST_Intersection(projected.geom, ST_MakeEnvelope(
        ST_XMin(projected.geom), ST_YMin(projected.geom),
        (ST_XMin(projected.geom) + ST_XMax(projected.geom)) / 2,
        ST_YMax(projected.geom), 2236)), 4326))
FROM (SELECT ST_Transform(geom, 2236) AS geom
      FROM demo.parcels WHERE parcel_id = 'SYNTH-000') AS projected;

INSERT INTO demo.flood_zones (indicator_id, source_id, geom)
SELECT 'SYN-FLD-01', 'SYN-FLD', ST_Multi(ST_Transform(
    ST_Intersection(projected.geom, ST_MakeEnvelope(
        ST_XMin(projected.geom), ST_YMin(projected.geom),
        (ST_XMin(projected.geom) + ST_XMax(projected.geom)) / 2,
        ST_YMax(projected.geom), 2236)), 4326))
FROM (SELECT ST_Transform(geom, 2236) AS geom
      FROM demo.parcels WHERE parcel_id = 'SYNTH-001') AS projected;

CREATE INDEX IF NOT EXISTS environmental_source_coverage_geom_gist
    ON demo.environmental_source_coverage USING gist (geom);
CREATE INDEX IF NOT EXISTS environmental_wetland_geom_gist
    ON demo.wetland_indicators USING gist (geom);
CREATE INDEX IF NOT EXISTS environmental_flood_geom_gist
    ON demo.flood_zones USING gist (geom);

CREATE OR REPLACE VIEW demo.environmental_indicators AS
SELECT source_id, geom FROM demo.wetland_indicators
UNION ALL
SELECT source_id, geom FROM demo.flood_zones;

-- SQL QA fails closed before producing the view. Typmods enforce SRID and type,
-- but validity, source completeness and coverage integrity are also checked.
DO $rank1$
BEGIN
    IF (SELECT count(*) FROM demo.parcels
        WHERE parcel_id IN ('SYNTH-000','SYNTH-001','SYNTH-002')) <> 3 THEN
        RAISE EXCEPTION 'Rank 1 fixture requires all three expected parcels';
    END IF;
    IF (SELECT count(*) FROM demo.environmental_source_register) <> 2
       OR (SELECT count(*) FROM demo.environmental_source_coverage) <> 4 THEN
        RAISE EXCEPTION 'Rank 1 source or coverage register is incomplete';
    END IF;
    IF EXISTS (
        SELECT 1 FROM demo.environmental_source_register AS s
        WHERE s.retrieved_on IS NULL OR s.dataset_name IS NULL
           OR s.source_url IS NULL OR btrim(s.known_limitations) = ''
           OR NOT EXISTS (SELECT 1 FROM demo.environmental_source_coverage AS c
                          WHERE c.source_id = s.source_id)
    ) THEN
        RAISE EXCEPTION 'Rank 1 metadata/coverage incomplete';
    END IF;
    IF EXISTS (
        SELECT 1 FROM demo.environmental_indicators AS i
        LEFT JOIN demo.environmental_source_register AS s USING (source_id)
        WHERE s.source_id IS NULL OR i.geom IS NULL OR ST_IsEmpty(i.geom)
           OR NOT ST_IsValid(i.geom) OR ST_SRID(i.geom) <> 4326
    ) THEN
        RAISE EXCEPTION 'Rank 1 indicator geometry or provenance invalid';
    END IF;
END
$rank1$;

-- Exhibit-ready TABULAR layer; not a regulatory constraint or final figure.
-- Areas use local projected EPSG:2236 (US survey feet). Coverage gaps are
-- explicit; never collapse unknown coverage into a zero-overlap assertion.
CREATE OR REPLACE VIEW demo.environmental_exhibit_summary AS
WITH candidate_parcels AS (
    SELECT parcel_id, ST_Transform(geom, 2236) AS geom
    FROM demo.parcels
    WHERE parcel_id IN ('SYNTH-000', 'SYNTH-001', 'SYNTH-002')
), source_shapes AS (
    SELECT s.*,
        (SELECT ST_UnaryUnion(ST_Collect(ST_Transform(c.geom, 2236)))
         FROM demo.environmental_source_coverage AS c
         WHERE c.source_id = s.source_id) AS coverage_geom,
        (SELECT ST_UnaryUnion(ST_Collect(ST_Transform(i.geom, 2236)))
         FROM demo.environmental_indicators AS i
         WHERE i.source_id = s.source_id) AS mapped_geom
    FROM demo.environmental_source_register AS s
), areas AS (
    SELECT p.parcel_id, s.source_id, s.constraint_type,
           s.dataset_name, s.publisher, s.retrieved_on, s.dataset_version,
           s.source_url, s.known_limitations,
           ST_Area(p.geom) AS parcel_sqft,
           COALESCE(ST_Area(ST_Intersection(p.geom, s.coverage_geom)), 0) AS covered_sqft,
           COALESCE(ST_Area(ST_Intersection(
               ST_Intersection(p.geom, s.coverage_geom), s.mapped_geom)), 0) AS overlap_sqft
    FROM candidate_parcels AS p CROSS JOIN source_shapes AS s
)
SELECT parcel_id, source_id, constraint_type, dataset_name, publisher,
       retrieved_on, dataset_version, source_url, known_limitations,
       2236::integer AS measurement_srid, 'US survey feet'::text AS linear_units,
       round((parcel_sqft / 43560)::numeric, 4) AS parcel_acres,
       round((covered_sqft / 43560)::numeric, 4) AS covered_acres,
       round((overlap_sqft / 43560)::numeric, 4) AS known_overlap_acres,
       round((100 * covered_sqft / NULLIF(parcel_sqft, 0))::numeric, 2) AS coverage_pct,
       round((100 * overlap_sqft / NULLIF(parcel_sqft, 0))::numeric, 2) AS overlap_pct,
       (overlap_sqft > 0) AS has_mapped_indicator,
       (covered_sqft < parcel_sqft - greatest(parcel_sqft * 1e-8, 1e-4)) AS data_gap_flag,
       CASE
           WHEN covered_sqft <= 0 THEN 'no_source_coverage'
           WHEN covered_sqft < parcel_sqft - greatest(parcel_sqft * 1e-8, 1e-4)
                THEN 'partial_source_coverage'
           WHEN overlap_sqft > 0 THEN 'intersects'
           ELSE 'no_mapped_intersection'
       END AS screening_status,
       'Synthetic desktop/database screen; not delineation, jurisdiction, Phase I ESA, survey or certification.'::text
           AS limitations_notice
FROM areas;

COMMIT;

SELECT parcel_id, constraint_type, screening_status, data_gap_flag,
       known_overlap_acres, coverage_pct, dataset_name, retrieved_on
FROM demo.environmental_exhibit_summary ORDER BY parcel_id, constraint_type;
