#!/usr/bin/env bash
#
# Boots `app_db` and applies the whole `app_db/app_schema` migration chain — the
# app server's [000]–[003] and this package's [004] — then runs the ops server's
# live suite against it and tears the database down again.
#
#   tom_core_samples/advanced_ops_server/tool/run_ops_integration.sh
#
# ## What this proves that the connection-free suites cannot
#
# Seven of the eight suites in this package run without a socket, and between
# them they cover every decision the package makes. What they cannot reach is the
# consequence of a call: `ops_retention_test.dart` counts one `destroy` per
# candidate, each carrying an entity, but its store is a stand-in — a repository
# that quietly stopped writing audit rows would leave that suite entirely green.
# `test/ops_live_test.dart` closes the loop by reading the trail back out of a
# real database, and it is the only artifact in the package that can.
#
# ## Why it is a runner and not just a test
#
# The live suite *skips* when `app_db` is unreachable, so `testkit :test` on a
# laptop with no docker stays green. A skip is only safe if something turns it
# back into a failure when the database was supposed to be there — that is this
# script's job (see `run_live_suite` below). Without it the suite would be a way
# to lose coverage silently.
#
# ## Why both databases, when the assertions only touch one
#
# Every suite in this package reads and writes `app_db`, and none of them
# addresses `auth_db` directly. `auth_db` is started anyway because the boot
# sequence — which the migration step below runs in full — initializes *all*
# declared datasources, and the digest resolves its recipients through the auth
# server's user repository. Starting only `app_db` fails at
# `initializeDatasourceInfo` with a connection refused on port 3307, long before
# any migration is applied.
#
# Requirements: docker (+ compose v2) and the Dart SDK on PATH. Host ports 3307
# and 3308 must be free or already serving this suite's databases. Both start
# from a *fresh* volume each run (`docker compose down -v`), so the initdb hooks
# re-apply their chains and the run sees the known seeded state.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SAMPLES="$(cd "$OPS_DIR/.." && pwd)"
APP_DIR="$SAMPLES/advanced_app_server"
AUTH_DIR="$SAMPLES/advanced_auth_server"

LOG_DIR="$(mktemp -d)"

log() { printf '\n=== %s ===\n' "$*"; }

cleanup() {
  local exit_code=$?
  set +e
  # On any non-zero exit — including a migration failure that aborts the run long
  # before the test step — dump what the migration boot logged, so the failure is
  # diagnosable after the temp LOG_DIR is removed below.
  if [ "$exit_code" -ne 0 ] && [ -s "$LOG_DIR/migrate.log" ]; then
    echo "--- ops migration log ---"
    cat "$LOG_DIR/migrate.log"
  fi
  log "Tearing down"
  (cd "$APP_DIR" && docker compose down -v) >/dev/null 2>&1
  (cd "$AUTH_DIR" && docker compose down -v) >/dev/null 2>&1
  rm -rf "$LOG_DIR"
}
trap cleanup EXIT

# Polls a container's docker health status until it reports `healthy`.
wait_db_healthy() {
  local name="$1" tries=60
  log "Waiting for database '$name' to become healthy"
  while [ "$tries" -gt 0 ]; do
    local status
    status="$(docker inspect -f '{{.State.Health.Status}}' "$name" 2>/dev/null || echo missing)"
    [ "$status" = "healthy" ] && return 0
    sleep 2
    tries=$((tries - 1))
  done
  echo "Database '$name' did not become healthy in time." >&2
  return 1
}

# 1. Fresh databases. `down -v` drops the old volumes so each server's migration
#    tree — mounted into the stock initdb hook by its compose file — re-applies
#    its chain on first boot ([000]–[003] for `app_db`).
#
#    No server is started. The live suite drives the ops services directly rather
#    than over HTTP (this server has no port), so the app server would only be a
#    second writer against the rows under assertion. `auth_db` is here for the
#    boot's sake, not the assertions' — see the header.
log "Starting app_db and auth_db (fresh volumes)"
(cd "$AUTH_DIR" && docker compose down -v >/dev/null 2>&1; docker compose up -d auth-db)
(cd "$APP_DIR" && docker compose down -v >/dev/null 2>&1; docker compose up -d app-db)
wait_db_healthy advanced-auth-db
wait_db_healthy advanced-app-db

# 2. Resolve dependencies for the package the run touches.
log "Resolving Dart dependencies"
(cd "$OPS_DIR" && dart pub get)

# 3. Apply [004]. The initdb hook mounts the *app server's* folder, so it has
#    never seen this package's file; and the engine records an applied version
#    per (datasource, schema) pair regardless of which package the folder sits
#    in, which is exactly what lets two packages share one chain.
#
#    `--migrate-only` rather than starting the server: a boot that started its
#    timers would put a second scheduler node on the same `tom_lease` rows the
#    live suite claims, and a purge firing beside the test would delete the rows
#    it seeded.
log "Applying this package's [004] migration"
(cd "$OPS_DIR" && dart run bin/ops_server_start.dart --migrate-only) \
  >"$LOG_DIR/migrate.log" 2>&1
tail -n 5 "$LOG_DIR/migrate.log"

# 4. Run the live suite. It skips rather than fails when `app_db` is unreachable
#    so the unit run stays green; here the database is guaranteed up, so a skip
#    means the suite could not reach what this script just built — which is a
#    failure, not an absence of work.
run_live_suite() {
  local label="$1" path="$2" output status
  log "Running $label"
  set +e
  output="$(cd "$OPS_DIR" && dart test "$path" 2>&1)"
  status=$?
  set -e
  printf '%s\n' "$output"

  if [ "$status" -eq 0 ] && printf '%s' "$output" | grep -q 'All tests skipped'; then
    echo "$label was SKIPPED (app_db unreachable at test time) — treating as failure." >&2
    status=1
  fi
  return "$status"
}

result=0
run_live_suite "the ops live suite (audited deletes, blob export, framework tables)" \
  test/ops_live_test.dart || result=1

# 5. The connection-free suites too, in the same run — deliberately after the
#    live one and regardless of its outcome. They need no infrastructure, but a
#    change that breaks both halves is better seen in one run than found one boot
#    at a time, and `ops_framework_schema_test.dart` in particular is the
#    *prediction* the live scheduler tick above either confirms or contradicts:
#    seeing the two disagree in one output is what names the drift.
#
#    Enumerated rather than excluded by a tag: `dart test` can only exclude by
#    tag, and tagging the live suite would need a `dart_test.yaml` declaring the
#    tag in a sample suite that has none. A glob minus one name needs no new
#    configuration file to explain.
log "Running the connection-free suites"
unit_suites=()
for suite in "$OPS_DIR"/test/*_test.dart; do
  case "$suite" in */ops_live_test.dart) continue ;; esac
  unit_suites+=("$suite")
done
if ! (cd "$OPS_DIR" && dart test "${unit_suites[@]}"); then
  result=1
fi

exit "$result"
