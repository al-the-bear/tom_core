#!/usr/bin/env bash
#
# Boots `app_db` and `auth_db`, applies the whole `app_db/app_schema` migration
# chain — the app server's [000]–[099] band and this package's [100] — then runs
# the ops server's two live suites against them, then its connection-free ones,
# and tears the databases down again.
#
#   tom_core_samples/advanced_ops_server/tool/run_ops_integration.sh
#
# ## What this proves that the connection-free suites cannot
#
# Thirteen of the fifteen suites in this package run without a socket, and
# between them they cover every decision the package makes. What they cannot
# reach is the consequence of a call: `ops_retention_test.dart` counts one
# `destroy` per candidate, each carrying an entity, but its store is a stand-in —
# a repository that quietly stopped writing audit rows would leave that suite
# entirely green. `test/ops_live_test.dart` closes the loop by reading the trail
# back out of a real database, and `test/ops_privacy_live_test.dart` erases a
# user across both databases and reads what is left; they are the only artifacts
# in the package that can.
#
# ## Why it is a runner and not just a test
#
# The live suites *skip* when `app_db` is unreachable, so `testkit :test` on a
# laptop with no docker stays green. A skip is only safe if something turns it
# back into a failure when the database was supposed to be there — that is this
# script's job (see `run_live_suite` below). Without it the suites would be a way
# to lose coverage silently.
#
# ## Why both databases
#
# `ops_privacy_live_test.dart` asserts against both: the user it erases has an
# account and a role assignment in `auth_db` and workspaces, items and comments
# in `app_db`. Even without it `auth_db` would have to be up, because the boot
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
#
#   run_ops_integration.sh --external-databases
#
# runs the suites against databases already up on 3307/3308, with this
# package's migration already applied — the sample deployed to a cluster, where
# the ops server applies it at start (advanced_deploy/run_kind_integration.sh).
# It starts and stops nothing; the suites read the credentials from
# APP_DB_PASSWORD / AUTH_DB_PASSWORD like the server does.
set -euo pipefail

EXTERNAL_DATABASES=0
for arg in "$@"; do
  case "$arg" in
    --external-databases) EXTERNAL_DATABASES=1 ;;
    *) echo "Unknown argument: $arg" >&2; exit 64 ;;
  esac
done

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
  if [ "$EXTERNAL_DATABASES" -eq 1 ]; then
    rm -rf "$LOG_DIR"
    return
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
#    its chain on first boot (the [000]–[099] band for `app_db`).
#
#    No server is started. The live suites drive the ops services and the auth
#    and app servers' repositories directly rather than over HTTP (this server has
#    no port), so a running server would only be a second writer against the rows
#    under assertion. Why both databases — see the header.
if [ "$EXTERNAL_DATABASES" -eq 1 ]; then
  log "Using the databases already running on 3307/3308"
  (cd "$OPS_DIR" && dart pub get)
else
log "Starting app_db and auth_db (fresh volumes)"
(cd "$AUTH_DIR" && docker compose down -v >/dev/null 2>&1; docker compose up -d auth-db)
(cd "$APP_DIR" && docker compose down -v >/dev/null 2>&1; docker compose up -d app-db)
wait_db_healthy advanced-auth-db
wait_db_healthy advanced-app-db

# 2. Resolve dependencies for the package the run touches.
log "Resolving Dart dependencies"
(cd "$OPS_DIR" && dart pub get)

# 3. Apply [100]. The initdb hook mounts the *app server's* folder, so it has
#    never seen this package's file; and the engine records an applied version
#    per (datasource, schema) pair regardless of which package the folder sits
#    in, which is exactly what lets two packages share one chain.
#
#    `--migrate-only` rather than starting the server: a boot that started its
#    timers would put a second scheduler node on the same `tom_lease` rows the
#    live suites claim, and a purge firing beside the tests would delete the rows
#    they seeded.
log "Applying this package's [100] and [101] migrations"
(cd "$OPS_DIR" && dart run bin/ops_server_start.dart --migrate-only) \
  >"$LOG_DIR/migrate.log" 2>&1
tail -n 5 "$LOG_DIR/migrate.log"
fi

# 4. Run the live suites. They skip rather than fail when `app_db` is
#    unreachable so the unit run stays green; here the database is guaranteed up,
#    so a skip means a suite could not reach what this script just built — which
#    is a failure, not an absence of work.
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
run_live_suite "the privacy live suite (a user exported and erased across both databases)" \
  test/ops_privacy_live_test.dart || result=1
run_live_suite "the audit-report live suite (a saved question delivered from the trail)" \
  test/ops_audit_reports_live_test.dart || result=1

# 5. The connection-free suites too, in the same run — deliberately after the
#    live ones and regardless of their outcome. They need no infrastructure, but a
#    change that breaks both halves is better seen in one run than found one boot
#    at a time, and `ops_framework_schema_test.dart` in particular is the
#    *prediction* the live scheduler tick above either confirms or contradicts:
#    seeing the two disagree in one output is what names the drift.
#
#    Enumerated rather than excluded by a tag: `dart test` can only exclude by
#    tag, and tagging the live suites would need a `dart_test.yaml` declaring the
#    tag in a sample suite that has none. A glob minus three names needs no new
#    configuration file to explain.
log "Running the connection-free suites"
unit_suites=()
for suite in "$OPS_DIR"/test/*_test.dart; do
  case "$suite" in */ops_live_test.dart | */ops_privacy_live_test.dart | */ops_audit_reports_live_test.dart) continue ;; esac
  unit_suites+=("$suite")
done
if ! (cd "$OPS_DIR" && dart test "${unit_suites[@]}"); then
  result=1
fi

exit "$result"
