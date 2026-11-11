#!/usr/bin/env bash
#
# Runs the DB-backed test surfaces against a throwaway MariaDB.
#
# The DB-tagged suites (`--tags db`) self-skip when no server is reachable, so
# the default `testkit :test` run stays green everywhere. This script provides
# the server they need: it boots the bundled `docker-compose.test.yaml` MariaDB
# on host port 3309, waits for it to become healthy, runs the DB-tagged tests
# against it, and tears it down again — one command for the "DB surfaces pass"
# check.
#
#   tom_core_server/tool/run_db_tests.sh
#
# Requirements: docker (+ compose v2), the Dart SDK and testkit on PATH — the
# Tom binaries the workspace setup builds (`tom_binaries/tom/<platform>/`; see
# _copilot_guidelines/tool_dependencies.md). Host port 3309
# must be free. The database starts from a fresh volume each run, and every
# suite file creates (and afterwards drops) a database of its own inside it.
set -euo pipefail

# testkit runs the suites. Checked before anything is booted: without it the
# script would start a database, fail at the last step and tear it down having
# run nothing.
if ! command -v testkit >/dev/null 2>&1; then
  echo "testkit is not on PATH. It is one of the Tom binaries the workspace setup" >&2
  echo "builds and puts on PATH (tom_binaries/tom/<platform>/, see" >&2
  echo "_copilot_guidelines/tool_dependencies.md); fix the setup rather than this script." >&2
  echo "The same run by hand, from tom_core_server/:" >&2
  echo "  docker compose -f docker-compose.test.yaml up -d --wait && dart test --tags db" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.test.yaml"

log() { printf '\n=== %s ===\n' "$*"; }

cleanup() {
  log "Tearing down test database"
  (cd "$PROJECT_DIR" && docker compose -f "$COMPOSE_FILE" down -v) >/dev/null 2>&1 || true
}
trap cleanup EXIT

log "Starting test MariaDB (docker-compose.test.yaml, port 3309)"
(cd "$PROJECT_DIR" && docker compose -f "$COMPOSE_FILE" up -d)

log "Waiting for the database container to become healthy"
tries=60
while [ "$tries" -gt 0 ]; do
  status="$(docker inspect --format '{{.State.Health.Status}}' \
    tom-core-server-test-db 2>/dev/null || echo 'starting')"
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

log "Running DB-tagged tests"
cd "$PROJECT_DIR"
# testkit drives `dart test`; `--tags db` selects only the DB-backed suites,
# which now find a reachable server and run instead of skipping.
#
# Concurrency is the package's own setting, not this script's: dart_test.yaml
# runs suite files one at a time, because two suites change the process-wide
# working directory. The database is not part of that reason — each suite file
# provisions a database of its own (test/fixtures/test_database.dart), so no
# suite, and no second run against the same server, can truncate or drop
# another's tables.
testkit :test --test-args="--tags db"
