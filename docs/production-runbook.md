# PostGIS production runbook

This runbook turns the cookbook patterns into an operational checklist. It is a starting point, not a substitute for a service-specific SLO, security review, or recovery exercise.

## 1. Before accepting data

1. **Define the spatial contract:** geometry type, SRID, dimensionality (XY/XYZ), null/empty policy, business-key uniqueness, expected extent, and units.
2. **Load into staging:** preserve the source and ingestion identifier; record row counts and load timestamps.
3. **Profile before repair:** count null and empty geometries, invalid features with `ST_IsValidReason`, SRIDs, geometry types, duplicate keys, and out-of-domain coordinates.
4. **Repair explicitly:** write a separate repaired output, record before/after counts and geometry types, and review area/length deltas. Never silently replace source geometry.
5. **Promote atomically:** run contract assertions before swapping a staging table or publishing a version. Keep a rollback path to the previous validated dataset.

Example invalid-geometry triage:

```sql
SELECT
    source_id,
    (ST_IsValidDetail(geom)).reason AS reason,
    ST_AsText((ST_IsValidDetail(geom)).location) AS location
FROM staging.incoming_features
WHERE geom IS NOT NULL
  AND NOT ST_IsValid(geom);
```

Replace `source_id`, schema, and table names with your actual ingestion contract. Do not run the example unchanged against production without reviewing its scope.

## 2. CRS and measurement controls

- Enforce SRID and geometry type in column definitions where the contract is stable.
- Use `ST_SetSRID` only to assign metadata to coordinates already known to be in that CRS; use `ST_Transform` to transform coordinates.
- Use geography for spheroid-aware distance/area on longitude/latitude, or a suitable local projected CRS with documented units and distortion.
- Do not use EPSG:3857 for authoritative area, length, or buffer measurements.
- Check transformation coverage and grid dependencies before processing data outside the region used during development.
- Record the input CRS, output CRS, measurement units, and transformation assumptions in deliverable metadata.

## 3. Index and query-plan workflow

1. Create the index that matches the predicate actually used: typically GiST on geometry; expression GiST for repeated `geom::geography` predicates; B-tree for selective attributes; BRIN only where physical row order correlates with the indexed value.
2. Run `ANALYZE` after bulk loads and significant distribution changes.
3. Use `EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)` on representative data in a safe environment.
4. Inspect estimated versus actual rows, loops, shared reads/hits, sort method, rechecks, and time spent below the most expensive node.
5. Compare equivalent query variants and record dataset size, Postgres/PostGIS versions, settings, warm/cold-cache context, and results.
6. Do not assert that every query must use an index. A sequential scan is correct when the table is small or a large fraction of rows qualifies.

Start with the read-only benchmark file: `scripts/benchmark_queries.sql`. Its tiny demo dataset validates query syntax and exposes plan shape; it does **not** demonstrate production-scale performance.

## 4. Index changes and migrations

- Build large indexes with `CREATE INDEX CONCURRENTLY` where reducing write blocking is required. It cannot run inside a transaction block; ensure the migration tool supports that behavior.
- Monitor concurrent index creation to completion and verify `pg_index.indisvalid` before relying on the index.
- Avoid creating duplicate indexes with equivalent leading columns and operators without measured justification.
- Re-run `ANALYZE` after bulk loads and after major data distribution changes.
- Validate index usage over a representative observation window before removing an existing index.
- For partitioned tables, design parent/child index behavior and retention together; verify partition pruning with an explicit date-bounded query.

## 5. Spatial data API and tile delivery

- Bind application values as parameters; never interpolate untrusted text into SQL.
- Apply tenant, jurisdiction, access-control, and time filters before exposing feature attributes or tile payloads.
- Transform into the delivery CRS once per query where practical; clip to the tile envelope and return only attributes the client needs.
- Version tile caches when source data or styling changes. Define invalidation and stale-data expectations.
- Test edge tiles, empty tiles, large geometries, antimeridian/high-latitude behavior where relevant, and authorization boundaries.
- Do not treat a KNN shortlist as proof of the exact spheroidal nearest feature unless the candidate strategy proves that guarantee. Use an exact-distance query when correctness is mandatory and scale the candidate strategy deliberately.

## 6. Partitioning and retention

Partition only when query pruning, retention, or lifecycle operations justify the operational complexity.

- Choose a key that aligns with common filters and retention policy.
- Ensure incoming rows always have a destination partition; define a controlled path for late or out-of-range data.
- Test pruning with `EXPLAIN` and bounded predicates on the partition key.
- Document retention and archive behavior, including whether backups include detached or external partitions.
- Monitor partition count, per-partition row distribution, index size, and autovacuum/statistics freshness.
- Avoid unbounded per-period partition creation without an automated lifecycle policy.

## 7. Security and reliability

- Use least-privilege roles; the local Compose demo uses `trust` authentication and is for disposable local use only.
- Keep database ports private, require TLS for remote connections, and apply network policy at the deployment boundary.
- Store credentials in a secret manager, rotate through a tested process, and never commit connection strings containing secrets.
- Define connection, statement, idle-transaction, and pool limits at the application boundary.
- Include PostGIS and required extensions, roles, grants, and configuration in restore procedures.
- Test restoring to a clean environment and run data-contract checks before routing production traffic to the restored service.
- Monitor database availability, query latency, lock waits, connection saturation, replication lag where applicable, storage growth, failed jobs, and backup freshness.

## 8. Release checklist

- [ ] Input/output CRS and units documented.
- [ ] Staging QA results and rejected-row policy recorded.
- [ ] Query plans reviewed on representative data.
- [ ] Indexes and statistics verified.
- [ ] Migration tested, including rollback and lock behavior.
- [ ] Backup restoration tested on a clean target.
- [ ] Permissions and sensitive location-data handling reviewed.
- [ ] Runtime and PostGIS versions recorded.
- [ ] Operational owner, alert thresholds, and recovery procedure documented.
- [ ] Post-release validation query and rollback trigger identified.

## 9. Rank 1 subcontract exhibit delivery checklist

**Synthetic example only; desktop/database analysis, not a field wetland delineation, jurisdictional determination, Phase I ESA, survey, certification or permit approval.** A consulting firm's responsible professional must validate regulatory context and final exhibits separately.

- [ ] Intake: document requested exhibit list, delivery formats, parcel IDs, general extent, client-provided licenses, permissible use and reviewer.
- [ ] Source and date: preserve immutable input source register (publisher, dataset, retrieval/effective dates or explicit unknown, version/URL, coverage, spatial resolution/known limitations).
- [ ] CRS: validate original CRS/SRID; transform for calculations; record EPSG:2236 **US survey feet** and acre conversion if used for Florida East demonstration.
- [ ] QA: reject null/empty/invalid geometries and mismatched SRID; check duplicates and union same-type overlaps to prevent double count.
- [ ] Unknowns: distinguish no mapped hit from no/partial data coverage, boundary uncertainty and any source disagreement.
- [ ] Exhibit set: verify page/scale/legend, north arrow as applicable, source citation, figure IDs, revision register, clipped layers and reproducibility.
- [ ] Handoff: deliver source register, per-parcel screening matrix, geometry exports, QA findings, disclaimers, file inventory and explicit review/sign-off responsibilities.
- [ ] Never label an unreviewed GIS preview `permit-approved`, `delineated` or a completed client engagement.
