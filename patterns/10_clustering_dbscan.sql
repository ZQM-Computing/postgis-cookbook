-- Pattern 10: DBSCAN clustering of points
-- Group nearby points into clusters using ST_ClusterDBSCAN with eps and
-- minpoints; noise points get cluster_id NULL.
SELECT id, ST_ClusterDBSCAN(geom, eps := 0.01, minpoints := 5) OVER () AS cid
FROM points;
