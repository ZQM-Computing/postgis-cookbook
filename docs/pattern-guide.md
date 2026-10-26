# Pattern guide

The SQL files are the runnable reference. This guide records the decisions behind them so the patterns can be adapted without copying the demo blindly.

## Geometry or geography?

| Need | Prefer | Why |
| --- | --- | --- |
| Store longitude/latitude and run topological predicates | `geometry(..., 4326)` | Full PostGIS function support and explicit SRID typing |
| Distance or area in meters on longitude/latitude data | Cast to `geography` | Spheroid-aware measurement without choosing a local projection |
| Area, length, buffering, or overlay in a local projected CRS | Transform to that CRS | Planar operations in known units, with projection distortion understood |
| Web-map display | Transform at the delivery boundary, often EPSG:3857 | Keeps storage and measurement semantics separate from display |

Never calculate meaningful area or distance in EPSG:3857. Web Mercator is a display projection, not a measurement system.

For the Florida-shaped demo, EPSG:2236 (Florida State Plane East, US survey feet) is the projected example. The same pattern applies with the appropriate State Plane, UTM, or national grid elsewhere.

## Index selection

| Index | Use it when | Watch out for |
| --- | --- | --- |
| GiST on `geometry` | Default choice for overlap, intersection, containment, and many nearest-neighbor workloads | Write and storage cost on frequently updated layers |
| GiST on `(geom::geography)` | Repeated meter-based `ST_DWithin` or distance work on longitude/latitude data | The query must use the same expression for the index to match |
| SP-GiST | Point-heavy or non-overlapping partitioned space workloads where its partitioning fits better than GiST | Benchmark; it is not a universal upgrade |
| BRIN on time or a physically correlated column | Very large, append-mostly tables whose rows are stored roughly in value order | Useless when physical order is random |
| Partial GiST | A stable, selective subset is queried constantly — for example, active or conservation parcels | Too many narrow indexes can cost more than they save |
| Expression index | The application repeatedly filters or orders by the same derived spatial expression | The expression in the query must match the indexed expression |

An index is not finished when it is created. Confirm the planner uses it on representative data, then re-check after major loads and version upgrades.

## Write predicates the planner can use

Prefer:

```sql
WHERE ST_DWithin(site.geom::geography, search_point::geography, 5000)
```

Avoid filtering on the result of a distance calculation:

```sql
-- Anti-pattern: computes distance for candidate rows before filtering.
WHERE ST_Distance(site.geom::geography, search_point::geography) <= 5000
```

Likewise, avoid wrapping the indexed column in a transform inside the predicate when the search geometry can be transformed once instead.

## Spatial joins

- Use `ST_Covers` or `ST_Contains` when boundary inclusion matters; use `ST_Intersects` when any touch should match.
- Join on the spatial predicate directly. Do not precompute every pair of distances.
- For nearest neighbors, use a lateral join ordered by the KNN operator (`<->`). Remember that `<->` orders by bounding-box center distance for non-point geometries; re-rank with an exact `ST_Distance` when the business answer requires true nearest geometry.
- Keep non-spatial filters selective and indexed too. A spatial index does not rescue a missing index on a high-cardinality status, tenant, or time predicate.

## Tiling and simplification

- Subdivide very large polygons before repeated intersection or tile generation with `ST_Subdivide`.
- Simplify for the delivery scale, not for storage. Keep the authoritative geometry intact and simplify in the tile or export query.
- `ST_SimplifyPreserveTopology` reduces the chance of collapsed or self-intersecting output; it does not make an arbitrary tolerance safe.
- For vector tiles, transform once into the tile CRS, clip with `ST_AsMVTGeom`, and keep only the attributes the client actually needs.

## Data-quality gates

Before a spatial layer is promoted, check:

- Invalid geometries and `ST_IsValidReason` output.
- Empty geometries and null geometries where the contract requires a feature.
- SRID inventory across geometry columns.
- Exact duplicate geometries and duplicate business keys.
- Geometry type drift — for example, Polygon rows arriving in a MultiPolygon layer.
- Areas or lengths that are impossible for the layer's domain.

Repair with `ST_MakeValid` in a staging step, preserve the source value, and record what changed. Silent in-place repair makes later audits difficult.

## Partitioning and maintenance

Partition when lifecycle or query patterns align with the partition key — commonly event time, jurisdiction, or ingestion batch. Do not partition a modest table just because the feature exists.

For large spatial tables, monitor:

- Table and index size by relation.
- Dead tuples and autovacuum progress.
- Index bloat after bulk updates or deletes.
- Long-running spatial joins by normalized query.
- Statistics freshness after bulk load.

Use `CREATE INDEX CONCURRENTLY` for large production tables, and treat the migration runner's transaction behavior as part of the design.

## Production checklist

- [ ] Geometry type and SRID are enforced by the column type.
- [ ] Geometry validity is checked at ingest or promotion.
- [ ] Spatial and non-spatial predicates both have an index strategy.
- [ ] Query plans were reviewed on representative volume.
- [ ] Bulk-load process includes `ANALYZE`.
- [ ] Backup and restore have been tested, including extensions.
- [ ] Version upgrades test spatial functions and planner behavior.
- [ ] No real sensitive location data appears in examples, fixtures, or issues.

## Row-level security and spatial data

- Prefer stable attribute predicates (for example, \`tenant_id\` or \`jurisdiction_id\`) when they express the authorization rule. They are usually simpler to reason about and can be cheaper than evaluating a geometry predicate for every candidate row.
- When the rule is genuinely geometric, use \`ST_Intersects\` or \`ST_Covers\` against a small, controlled lookup table of service areas or jurisdictions. Choose the predicate deliberately: boundary-touching features may match \`ST_Intersects\`.
- Grant the policy roles only the schema and table privileges they require. Row-level security filters rows; it does not replace ordinary SQL privileges or protect against superusers and roles with \`BYPASSRLS\`.
- Test policies with \`SET ROLE\` / \`RESET ROLE\`, including both permitted and excluded rows. Review \`EXPLAIN\` plans on representative data; do not assume a spatial index will be used simply because a GiST index exists.
- \`FORCE ROW LEVEL SECURITY\` also subjects table owners to policies, but superusers and \`BYPASSRLS\` roles can still bypass them. Design owner, migration, and application roles explicitly.
- Treat policy DDL and role grants as migrations. The cookbook example uses a transaction and uniquely named disposable roles, and removes them on success so later patterns and CI see the original fixture. Production policies should be managed through reviewed migrations, not copied with demo role names.
