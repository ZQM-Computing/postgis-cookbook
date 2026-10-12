#!/usr/bin/env bash
set -euo pipefail

# Wait until PostgreSQL is *really* ready -- not just answering pg_isready.
#
# The postgres image entrypoint starts a temporary server while it runs its
# init steps, then restarts PostgreSQL for normal operation. pg_isready (and
# even a successful query) can succeed against that temporary server, and
# the restart then kills client connections mid-run with:
#   FATAL: terminating connection due to administrator command
# So readiness here means: pg_postmaster_start_time() is identical across
# two probes a few seconds apart -- something only the final, post-init
# server satisfies.

probe_start_time() {
  docker compose exec -T db psql -U patterns -d postgis_patterns \
    -t -A -c "SELECT pg_postmaster_start_time();" 2>/dev/null || true
}

deadline=$((SECONDS + 120))
while [ "${SECONDS}" -lt "${deadline}" ]; do
  first="$(probe_start_time)"
  if [ -n "${first}" ]; then
    sleep 3
    second="$(probe_start_time)"
    if [ -n "${second}" ] && [ "${first}" = "${second}" ]; then
      exit 0
    fi
  fi
  sleep 2
done

echo "PostGIS did not become ready (no stable postmaster) within 120 seconds." >&2
exit 1
