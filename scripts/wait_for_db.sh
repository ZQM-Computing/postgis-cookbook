#!/usr/bin/env bash
set -euo pipefail

# Wait until PostgreSQL is *really* ready -- not just answering pg_isready.
#
# The postgres image entrypoint starts a temporary server while it runs its
# init steps, then restarts PostgreSQL for normal operation. pg_isready (and
# even a successful query) can succeed against that temporary server, and
# the restart then kills client connections mid-run with:
#   FATAL: terminating connection due to administrator command
# Socket connections can still reach the temporary initialization server, and
# two probes can hit it before the entrypoint restarts PostgreSQL. Force TCP:
# the temporary server does not listen on 127.0.0.1, so a successful query
# proves the final server is accepting network connections. Keep the stable
# postmaster-time check as a second guard against restarts during startup.

probe_start_time() {
  docker compose exec -T db psql -h 127.0.0.1 -U patterns -d postgis_patterns \
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
