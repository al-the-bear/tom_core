#!/usr/bin/env bash
#
# End-to-end verification of multi_tenant_sample, on MariaDB and on
# PostgreSQL: for each engine it brings a fresh database up, runs the live
# suite (test/live_scenario_test.dart) against it, and tears it down; then it
# runs the suites that need no database. One command, one exit code.
#
#   ./tool/run_integration.sh              # both engines
#   ./tool/run_integration.sh mariadb      # one
#
# The live suite skips when no database answers, so that `dart test` stays
# green without Docker; here a skip would hide a dead stack, so the runner
# fails on one (`MT_REQUIRE_DB=1`).
#
# Requirements: Docker with Compose v2, a Dart SDK on PATH, host ports 3341 and
# 5441 free. Nothing is left running: the EXIT trap tears the stack down.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PACKAGE_DIR"

if [ "$#" -gt 0 ]; then
  ENGINES=("$@")
else
  ENGINES=(mariadb postgresql)
fi

log() { printf '\n=== %s ===\n' "$*"; }

cleanup() {
  log "Tearing down"
  docker compose down -v --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT

for engine in "${ENGINES[@]}"; do
  case "$engine" in
    mariadb) service=mariadb ;;
    postgresql) service=postgres ;;
    *) echo "unknown engine: $engine" >&2; exit 2 ;;
  esac
  log "$engine: fresh database"
  docker compose down -v --remove-orphans >/dev/null 2>&1 || true
  docker compose up -d --wait "$service"
  log "$engine: live suite"
  MT_DB_ENGINE="$engine" MT_REQUIRE_DB=1 dart test --tags live --reporter expanded
done

log "Suites without a database"
dart test --exclude-tags live

log "All tests passed!"
