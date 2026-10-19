#!/usr/bin/env bash
#
# Runs the DB-backed test surfaces against a throwaway PostgreSQL — the same
# suites tool/run_db_tests.sh runs against MariaDB.
#
# The DB-tagged suites (`--tags db`) self-skip when no server is reachable. This
# script boots the bundled `docker-compose.test.postgres.yaml` PostgreSQL on
# host port 5439 (with prepared transactions enabled, for the two-phase data
# source), waits for it to become healthy, runs the DB-tagged tests against it
# with TOM_CORE_SERVER_TEST_DB_ENGINE=postgresql, and tears it down again.
#
#   tom_core_server/tool/run_db_tests_postgres.sh
#
# Requirements: docker (+ compose v2) and the Dart SDK on PATH. Host port 5439
# must be free. The database starts from a fresh volume each run, and every
# suite file creates (and afterwards drops) a database of its own inside it.
#
# A test of a behaviour only MariaDB has — the MariaDB client's own protocol,
# MariaDB's account syntax — skips itself here with the reason stated
# (`TestDatabase.onlyOnMariaDb`); everything the framework does on every
# database runs on both.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.test.postgres.yaml"

log() { printf '\n=== %s ===\n' "$*"; }

cleanup() {
  log "Tearing down test database"
  (cd "$PROJECT_DIR" && docker compose -f "$COMPOSE_FILE" down -v) >/dev/null 2>&1 || true
}
trap cleanup EXIT

log "Starting test PostgreSQL (docker-compose.test.postgres.yaml, port 5439)"
(cd "$PROJECT_DIR" && docker compose -f "$COMPOSE_FILE" up -d)

log "Waiting for the database container to become healthy"
tries=60
while [ "$tries" -gt 0 ]; do
  status="$(docker inspect --format '{{.State.Health.Status}}' \
    tom-core-server-test-pg 2>/dev/null || echo 'starting')"
  if [ "$status" = "healthy" ]; then
    break
  fi
  tries=$((tries - 1))
  sleep 2
done
if [ "$tries" -eq 0 ]; then
  echo "Test database did not become healthy in time." >&2
  exit 1
fi

log "Running DB-tagged tests against PostgreSQL"
cd "$PROJECT_DIR"
export TOM_CORE_SERVER_TEST_DB_ENGINE=postgresql
testkit :test --test-args="--tags db"
