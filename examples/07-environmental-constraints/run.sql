-- Rank 1 read-only environmental exhibit output example.
-- SYNTHETIC data only; desktop/database demonstration, not delineation,
-- jurisdictional determination, Phase I ESA, survey or certification.
-- Input / coverage / uncertainty and source+retrieval date are required.
-- First execute bash scripts/run_examples.sh from the repository root.
SELECT parcel_id, constraint_type, screening_status, has_mapped_indicator,
       data_gap_flag, parcel_acres, known_overlap_acres, coverage_pct,
       dataset_name, publisher, retrieved_on, source_url, known_limitations
FROM demo.environmental_exhibit_summary
ORDER BY parcel_id, constraint_type;
