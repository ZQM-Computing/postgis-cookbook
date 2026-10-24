-- Example 05: ST_ClusterDBSCAN clustering
-- Run with: psql -f examples/05-cluster-dbscan/run.sql

SELECT id, geom,
  ST_ClusterDBSCAN(geom, 0.01, 2) OVER () AS cluster_id
FROM locations;
