# PostGIS migration discovery — scoped commercial deliverable

This template supports ZQM Computing's proposed **$2,000–$4,000 migration
discovery** engagement. The fee is a market test, **not a quotation or an
assertion about prevailing prices**. Production migration, full cleanup,
software licenses, hosting and ongoing support are separate.

The work is an evidence-based **discovery and go/no-go assessment**, not a
certification, survey, engineering opinion, environmental site assessment or
regulatory determination. Replace every placeholder only after an
**authorized** client engagement; do not commit completed client reports,
samples, connection strings or credentials to this public repository.

## Buyer outcome

The buyer receives a source/target inventory, an explicit spatial and
attribute reconciliation plan, prioritized risks, acceptance criteria,
recovery assumptions, and a separately scoped migration implementation
option. If evidence does not support migration, the report should say so.

**Fit gate:** a named workflow and dataset owner; authorized access to
metadata or representative samples; a defined consumer of the future data;
an identified decision maker; and a realistic purchasing process.

## 1. Identity, authority and boundaries

| Control | Client-confirmed detail |
| --- | --- |
| Current system(s) / versions | [Database, service, desktop and provider versions] |
| Target system(s) / versions | [Destination, extensions, hosting, retention] |
| Business outcome | [What a successful migration changes] |
| Data steward / approval authority | [Role, access permissions and decisions] |
| Sample permissions | [Allowed metadata, authorized extracts and handling] |
| Security / classification | [PII, confidential geometry, export restrictions] |
| Geographic extent / precision | [Coverage, horizontal/vertical references, units] |
| Out-of-scope systems | [Explicit exclusions] |
| Data rights and deliverable ownership | [Contracted terms] |
| Baseline evidence date | [Collection date and method] |

Prefer schema descriptions, documented interfaces and approved samples.
**Do not request production passwords for initial qualification.** Read-only
metadata access, a supervised screen-share or offline samples often suffice.
Review retention, encryption, access control and deletion requirements with
the data steward before collection.

## 2. Source inventory and compatibility

Complete one row per *source dataset* rather than assuming everything is a
single homogeneous spatial table.

| Source | Format / owner | Features / volume | Geometry / dimensions | Source CRS / SRID | Business key | Dependencies | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| [Name] | [PostGIS, file, GIS service, etc.] | [Measured or unknown] | [Point/line/polygon, XY/XYZ] | [Declared / missing] | [Stable ID or missing] | [Views, functions, consumers] | [Observed, estimated, unknown] |

Capture relevant field types, precision, nullability, constraints, indexes,
foreign keys, temporal semantics, encoding, raster bands/nodata if applicable,
partitioning, privileges and backup/restore limitations. Record the actual
source versions and date used for every compatibility assertion.

## 3. Reconciliation and spatial correctness contract

The proposed implementation must define *before the first migration attempt*:

- Input count, rejected/quarantined count and target count by source/table.
- Identity matching and duplicate-ID policy; legitimate one-to-many
  transformations must have a documented expansion accounting.
- Column mapping, null policy, type coercions and domain validation.
- Geometry validity, empties, mixed types, Z/M dimensions, axis order,
  precision, topology and transformations.
- CRS assignments versus transformations: `ST_SetSRID` does **not**
  transform coordinates; `ST_Transform` does.
- Coordinate units and appropriate projected/geography measurement choices;
  do not assume EPSG:3857 is suitable for authoritative measurement.
- Spatial boundary rules (contains vs covers vs intersects), tolerance and
  representative edge cases.
- Data lineage: stable source IDs, batch/run identifier, rejected reason codes,
  source and destination version/hash when appropriate.
- Row-by-row or aggregate value checks for client-approved critical attributes.

| Invariant | Sample or query evidence | Proposed acceptance threshold | Decision owner |
| --- | --- | --- | --- |
| Count reconciliation | [Input / accepted / rejected] | [Exact rule] | [Role] |
| Keys and duplicates | [Observed key profile] | [Uniqueness/null rule] | [Role] |
| Geometry and CRS | [Type, SRID, validation] | [Allowed deviation] | [Role] |
| Critical attributes | [Sample comparison] | [Equality/tolerance] | [Role] |
| Spatial query outputs | [Known expected results] | [Predicate/tolerance] | [Role] |
| Recovery and repeatability | [Proposed dry-run] | [Rollback and rerun rule] | [Role] |

**A passing row count alone never proves migration correctness.** A
published destination must satisfy the agreed input-to-output reconciliation
and critical spatial/attribute invariants. Unknown requirements are risks,
not implicitly passing checks.

## 4. Discovery risk register

| Risk | Evidence or uncertainty | Likelihood / impact | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| [CRS ambiguity] | [Source or unknown] | [Rated with basis] | [Confirm authority / hold import] | [Role] |
| [Key collision] | [Profile result] | [Rated with basis] | [Quarantine and policy decision] | [Role] |
| [Access control] | [Consumer/role matrix] | [Rated with basis] | [Least privilege / explicit tests] | [Role] |
| [Downtime / rollback] | [Current RPO/RTO] | [Rated with basis] | [Dry-run and rollback plan] | [Role] |

Include permissions, data sensitivity, downtime, external dependencies,
schema drift, licensing, cost, capacity and the risk of unsupported
assumptions. Identify unresolved blockers explicitly.

## 5. Implementation option (separate contract)

Draft a *bounded* implementation statement only where discovery supports it:

1. Source scope, transformation contract and expected target schema.
2. Approved staging and reject-handling mechanism; **source remains unchanged**.
3. Versioned dry-run plan, comparison queries and acceptance test fixtures.
4. Maintenance window, cutover gates, named decision maker and rollback plan.
5. Observability, ownership, backups and repeat-run strategy.
6. Post-cutover verification, documentation, training and handoff.
7. Cost categories: build, infrastructure, licenses, validation, support and
   human review; separate estimates from observed facts.
8. Milestone payment terms and approval for expansion.

Use the existing [production runbook](production-runbook.md), especially
its data quality, schema, index, security and recovery controls. Demonstration
patterns in [data quality](../patterns/05_data_quality.sql), [CRS
management](../patterns/03_coordinate_systems.sql) and [row-level
security](../patterns/07_row_level_security.sql) are **reference code on
synthetic fixtures**, not evidence that a particular client's migration
has been tested or approved.

## 6. Decision, delivery and handoff

**Recommendation:** [Proceed to a separately scoped implementation /
resolve prerequisites / retain current platform / insufficient evidence].

**Open decisions:** [Named owner, source of evidence and decision date].

**Customer review:** [Date, attendees, corrections, limitations acknowledged].

**Deliverables:** source/target inventory; documented mappings and
reconciliation strategy; risk register; acceptance/rollback criteria; and
a separately priced implementation scope or a no-go recommendation.

No changes to production databases are authorized by this discovery report.
