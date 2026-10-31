-- Controlled PostGIS spatial-index experiment using temporary synthetic tables.
-- Run after the standard demo is available:
-- docker compose exec -T db psql -U patterns -d postgis_patterns -v ON_ERROR_STOP=1 < scripts/benchmark_spatial_index.sql
--
-- Creates TEMP tables only; no persistent demo tables are changed.
-- Compare index-eligible and sequential-scan plans on uniform and clustered
-- point distributions. EXPLAIN ANALYZE executes the read-only SELECTs.
-- Planner enable_* settings are experimental controls, not production advice.

\set ON_ERROR_STOP on
\timing on

SELECT 'benchmark_context' AS section,
       current_setting('server_version') AS postgres_version,
       postgis_full_version() AS postgis_version,
       current_setting('work_mem') AS work_mem,
       now() AS captured_at;

-- Reproducible coordinates: generate_series IDs drive hash-based offsets;
-- no dependence on session random state.
CREATE TEMP TABLE bench_uniform AS
SELECT i::bigint AS id,
       ST_SetSRID(
           ST_MakePoint(
               -81.30 + ((('x' || substr(md5(i::text), 1, 8))::bit(32)::bigint % 1000000)::double precision / 1000000.0) * 0.60,
               28.90 + ((('x' || substr(md5(i::text || ':y'), 1, 8))::bit(32)::bigint % 1000000)::double precision / 1000000.0) * 0.60
           ),
           4326
       )::geometry(Point, 4326) AS geom
FROM generate_series(1, 200000) AS i;

-- Four dense clusters with small deterministic jitter, plus identical row count.
CREATE TEMP TABLE bench_clustered AS
SELECT i::bigint AS id,
       ST_SetSRID(
           ST_MakePoint(
               (ARRAY[-81.20, -81.05, -80.90, -80.75])[1 + (i % 4)]
                   + ((('x' || substr(md5(i::text), 1, 8))::bit(32)::bigint % 1000000)::double precision / 1000000.0 - 0.5) * 0.025,
               (ARRAY[29.05, 29.20, 29.30, 29.10])[1 + (i % 4)]
                   + ((('x' || substr(md5(i::text || ':y'), 1, 8))::bit(32)::bigint % 1000000)::double precision / 1000000.0 - 0.5) * 0.025
           ),
           4326
       )::geometry(Point, 4326) AS geom
FROM generate_series(1, 200000) AS i;

CREATE INDEX bench_uniform_geom_gix ON bench_uniform USING GIST (geom);
CREATE INDEX bench_clustered_geom_gix ON bench_clustered USING GIST (geom);
ANALYZE bench_uniform;
ANALYZE bench_clustered;

SELECT 'dataset_profile' AS section, 'uniform' AS distribution,
       count(*) AS rows, count(DISTINCT ST_SnapToGrid(geom, 0.01)) AS occupied_grid_cells,
       ST_Extent(geom) AS extent
FROM bench_uniform
UNION ALL
SELECT 'dataset_profile', 'clustered', count(*),
       count(DISTINCT ST_SnapToGrid(geom, 0.01)), ST_Extent(geom)
FROM bench_clustered;

-- The same small-area envelope is used for both distributions.
-- First, allow the planner to choose its preferred plan.
SET enable_seqscan = on;
SET enable_bitmapscan = on;
SET enable_indexscan = on;

\echo 'UNIFORM: planner-selected plan; selective envelope'
EXPLAIN (ANALYZE, BUFFERS, SETTINGS)
SELECT count(*) FROM bench_uniform
WHERE geom && ST_MakeEnvelope(-81.205, 29.045, -81.195, 29.055, 4326);

\echo 'CLUSTERED: planner-selected plan; selective envelope'
EXPLAIN (ANALYZE, BUFFERS, SETTINGS)
SELECT count(*) FROM bench_clustered
WHERE geom && ST_MakeEnvelope(-81.205, 29.045, -81.195, 29.055, 4326);

-- Controlled comparison: discourage sequential scans to expose the GiST path.
-- This does not prove that the index plan is faster; compare actual buffers
-- and execution time against the sequential scan below.
SET enable_seqscan = off;

\echo 'UNIFORM: index-eligible plan'
EXPLAIN (ANALYZE, BUFFERS, SETTINGS)
SELECT count(*) FROM bench_uniform
WHERE geom && ST_MakeEnvelope(-81.205, 29.045, -81.195, 29.055, 4326);

\echo 'CLUSTERED: index-eligible plan'
EXPLAIN (ANALYZE, BUFFERS, SETTINGS)
SELECT count(*) FROM bench_clustered
WHERE geom && ST_MakeEnvelope(-81.205, 29.045, -81.195, 29.055, 4326);

-- Controlled sequential-scan comparison.
SET enable_seqscan = on;
SET enable_indexscan = off;
SET enable_bitmapscan = off;

\echo 'UNIFORM: sequential-scan plan'
EXPLAIN (ANALYZE, BUFFERS, SETTINGS)
SELECT count(*) FROM bench_uniform
WHERE geom && ST_MakeEnvelope(-81.205, 29.045, -81.195, 29.055, 4326);

\echo 'CLUSTERED: sequential-scan plan'
EXPLAIN (ANALYZE, BUFFERS, SETTINGS)
SELECT count(*) FROM bench_clustered
WHERE geom && ST_MakeEnvelope(-81.205, 29.045, -81.195, 29.055, 4326);

-- Correctness: index and sequential-scan execution must return identical counts.
SET enable_indexscan = on;
SET enable_bitmapscan = on;
SET enable_seqscan = on;

WITH counts AS (
    SELECT 'uniform' AS distribution,
           (SELECT count(*) FROM bench_uniform
            WHERE geom && ST_MakeEnvelope(-81.205, 29.045, -81.195, 29.055, 4326)) AS result_count,
           (SELECT count(*) FROM bench_uniform
            WHERE ST_Intersects(geom, ST_MakeEnvelope(-81.205, 29.045, -81.195, 29.055, 4326))) AS exact_count
    UNION ALL
    SELECT 'clustered',
           (SELECT count(*) FROM bench_clustered
            WHERE geom && ST_MakeEnvelope(-81.205, 29.045, -81.195, 29.055, 4326)),
           (SELECT count(*) FROM bench_clustered
            WHERE ST_Intersects(geom, ST_MakeEnvelope(-81.205, 29.045, -81.195, 29.055, 4326)))
)
SELECT distribution, result_count, exact_count,
       result_count = exact_count AS bbox_matches_exact_for_envelope
FROM counts
ORDER BY distribution;

RESET enable_seqscan;
RESET enable_indexscan;
RESET enable_bitmapscan;
