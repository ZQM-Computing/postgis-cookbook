# Example 07 — synthetic environmental exhibit screening

**Synthetic demonstration only. Desktop/database work only.** Not a field wetland delineation, jurisdictional determination, Phase I ESA, boundary survey, regulatory approval, or professional certification. Consult qualified field professionals and current regulatory sources before property or permit decisions.

The numbered SQL pattern [`patterns/08_environmental_constraints.sql`](../../patterns/08_environmental_constraints.sql) constructs two synthetic indicator layers, three example parcels, source-coverage footprints, and a mandatory source/date/known-limitations register. It creates `demo.environmental_exhibit_summary` for a reviewable, per-parcel, per-source constraints table.

## Run

From the repository root:

```sh
docker compose up -d db
bash scripts/run_examples.sh
docker compose exec -T db psql -U patterns -d postgis_patterns -v ON_ERROR_STOP=1 \
  < examples/07-environmental-constraints/run.sql
```

The full runner already executes Pattern 08 before `tests/assertions.sql`. The example's `run.sql` is intentionally **read-only**, selecting from the generated table/view. It must be run after the synthetic setup, not against real client data.

## Review output

- `parcel_id`, `constraint_type` and `screening_status` identify candidate parcels, indicator type and mapped/coverage state.
- `has_mapped_indicator` and `data_gap_flag` distinguish **mapped overlap** from incomplete source coverage.
- `parcel_acres`, `covered_acres`, `known_overlap_acres`, `coverage_pct` and `overlap_pct` use EPSG:2236 **US survey feet**, converted from ft² at **43,560 ft²/acre**, with no false metre-based conversions.
- `dataset_name`, `publisher`, `retrieved_on`, `dataset_version`, `source_url` and `known_limitations` remain attached to each row.
- `no_mapped_intersection` means only that the synthetic *mapped* layer has no positive-area overlap within available coverage. It is **not** evidence that the property has no wetland, flood or legal constraints.

The example uses fictitious source links and synthetic geometry generated from the cookbook's synthetic parcel fixture. It does not access NWI, FEMA, real parcel data, client files, or agency services. Client-facing exhibit deliverables require independent source review, actual dataset licensing, file/figure QA, professional signoff as appropriate, and agreed delivery scope.
