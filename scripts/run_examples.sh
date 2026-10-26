#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
bash scripts/wait_for_db.sh

run_sql() {
  local file="$1"
  echo
  echo "==> ${file}"
  docker compose exec -T db psql \
    -U patterns \
    -d postgis_patterns \
    -v ON_ERROR_STOP=1 \
    < "${file}"
}

run_sql sql/00_extensions_and_schema.sql
run_sql sql/01_sample_data.sql
run_sql patterns/01_indexing.sql
run_sql patterns/02_spatial_joins.sql
run_sql patterns/03_coordinate_systems.sql
run_sql patterns/04_tiling_and_simplification.sql
run_sql patterns/05_data_quality.sql
run_sql patterns/06_partitioning_and_maintenance.sql
run_sql patterns/07_row_level_security.sql
run_sql tests/assertions.sql

echo
echo "postgis-cookbook: all examples and assertions completed."
