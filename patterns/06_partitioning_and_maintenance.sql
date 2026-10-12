-- Pattern 06: Partitioning and maintenance
-- Partition when retention, load, and query patterns align with the key.
-- This example partitions observations by year because the sample workload is
-- time-ordered and append-mostly.

CREATE TABLE IF NOT EXISTS demo.sensor_observations_partitioned (
    observation_id bigint GENERATED ALWAYS AS IDENTITY,
    site_id integer NOT NULL,
    observed_at timestamptz NOT NULL,
    reading_value numeric(8, 2) NOT NULL,
    geom geometry(Point, 4326) NOT NULL,
    PRIMARY KEY (observation_id, observed_at)
) PARTITION BY RANGE (observed_at);

CREATE TABLE IF NOT EXISTS demo.sensor_observations_2026
    PARTITION OF demo.sensor_observations_partitioned
    FOR VALUES FROM ('2026-01-01 00:00:00+00') TO ('2027-01-01 00:00:00+00');

-- Indexes declared on the partitioned parent are maintained for its
-- partitions. In production, create large indexes concurrently through a
-- migration process designed for that operation.
CREATE INDEX IF NOT EXISTS sensor_observations_partitioned_geom_gist
    ON demo.sensor_observations_partitioned USING gist (geom);

CREATE INDEX IF NOT EXISTS sensor_observations_partitioned_site_time_idx
    ON demo.sensor_observations_partitioned (site_id, observed_at DESC);

TRUNCATE TABLE demo.sensor_observations_partitioned;

INSERT INTO demo.sensor_observations_partitioned (
    site_id,
    observed_at,
    reading_value,
    geom
)
SELECT
    site_id,
    observed_at,
    reading_value,
    geom
FROM demo.sensor_observations
ORDER BY observed_at, site_id;

ANALYZE demo.sensor_observations_partitioned;

-- Show which physical partition received the rows.
SELECT
    tableoid::regclass::text AS partition_name,
    count(*) AS row_count,
    min(observed_at) AS first_observation,
    max(observed_at) AS last_observation
FROM demo.sensor_observations_partitioned
GROUP BY tableoid
ORDER BY partition_name;

-- Relation sizes make spatial growth and index cost visible.
SELECT
    c.relname AS relation_name,
    pg_size_pretty(pg_total_relation_size(c.oid)) AS total_size,
    pg_size_pretty(pg_relation_size(c.oid)) AS table_size,
    pg_size_pretty(pg_indexes_size(c.oid)) AS index_size
FROM pg_class AS c
JOIN pg_namespace AS n
    ON n.oid = c.relnamespace
WHERE n.nspname = 'demo'
  AND c.relkind IN ('r', 'p')
ORDER BY pg_total_relation_size(c.oid) DESC, c.relname;

-- Check whether statistics and vacuuming are keeping up. Null timestamps can
-- be normal on a fresh demo database; investigate persistent lag in production.
SELECT
    relname,
    n_live_tup,
    n_dead_tup,
    last_analyze,
    last_autoanalyze,
    last_autovacuum
FROM pg_stat_user_tables
WHERE schemaname = 'demo'
ORDER BY relname;
