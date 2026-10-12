#!/usr/bin/env bash
set -euo pipefail

for attempt in $(seq 1 30); do
  if docker compose exec -T db pg_isready -U patterns -d postgis_patterns >/dev/null 2>&1; then
    exit 0
  fi
  sleep 2
done

echo "PostGIS did not become ready after 60 seconds." >&2
exit 1
