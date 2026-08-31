#!/usr/bin/env bash
#
# End-to-end verification of core_server_sample: brings the bundled MariaDB and
# the sample server up on fresh state, proves the three public endpoints against
# them, then runs everything in the package that needs no database — one command,
# one exit code.
#
#   ./tool/run_integration.sh
#
# ## What this proves that the connection-free suites cannot
#
# `todo_persistence_mapping_test.dart` and `example/run_all_examples.dart` are
# pure: they exercise the domain <-> record mapping and the four-state
# authorizer without a socket. That is most of the package's logic and none of
# its claim. What makes this a *sample backend* is the part they cannot reach —
# the boot sequence in `bin/server_start.dart`, the datasource registration, the
# migration tree actually creating and seeding tables, the endpoint router
# resolving the `@tomComponent` behind the `@tomService`, and the reflection
# pipeline serializing the returned DTOs onto the wire. Every one of those could
# break with the whole repo still green.
#
# ## Why it is a runner and not just a test
#
# `test/todo_endpoints_integration_test.dart` *skips* when nothing is listening
# on :8080, so that `dart test` stays green on a laptop without Docker. That is
# the right default and it is also a blind spot: a skip is indistinguishable
# from a pass in the exit code. This script closes it. It brings the stack up
# itself and checks the database is healthy and the server answers /health
# before running anything, so at that point a skip can only mean the stack died
# in between — and the script converts it into a failure (see run_live_suite).
#
# ## Why the state is recreated every run
#
# `docker compose down -v` drops the volume, so the initdb hook replays the
# migration tree from scratch. The live suite asserts the *seeded* rows and the
# exact grant matrix, which is what turns /todos into a persistence proof rather
# than a "some JSON came back" check — and that only holds against known state.
# It also means the run is unaffected by whatever a previous manual session left
# in the database.
#
# ## Requirements
#
#   - Docker with Compose v2 (`docker compose`, not `docker-compose`).
#   - A Dart SDK on PATH.
#   - Host port 8080 free (the server), and 3306 free for the database — if
#     something else holds 3306, `docker compose up` fails immediately with
#     "port is already allocated"; set TODO_DB_PORT in a `.env` to move it, and
#     both compose and the datasource loader will follow, because they read the
#     same variable.
#
# Nothing is left running: the EXIT trap stops the server and tears the database
# down again, and dumps the server/test logs first whenever the run fails.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAMPLE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

LOG_DIR="$(mktemp -d)"
SERVER_PID=""

log() { printf '\n=== %s ===\n' "$*"; }

cleanup() {
  local exit_code=$?
  set +e

  # Dump before removing, and only when something went wrong: on a green run the
  # boot log is noise, on a red one it is usually the whole answer.
  if [ "$exit_code" -ne 0 ] && [ -s "$LOG_DIR/server.log" ]; then
    log "Server log (run failed)"
    cat "$LOG_DIR/server.log"
  fi

  if [ -n "$SERVER_PID" ]; then
    kill "$SERVER_PID" 2>/dev/null
    wait "$SERVER_PID" 2>/dev/null
  fi

  log "Stopping the database"
  (cd "$SAMPLE_DIR" && docker compose down -v >/dev/null 2>&1)

  rm -rf "$LOG_DIR"
  exit "$exit_code"
}
trap cleanup EXIT

# Refuse to start rather than run against something else's server. Only the HTTP
# port is guarded: the database is addressed through the container name, and the
# run recreates it anyway, so a stale `todo-db` is resolved by step 1 rather than
# being a reason to abort.
assert_server_port_free() {
  if (exec 3<>"/dev/tcp/127.0.0.1/8080") 2>/dev/null; then
    exec 3>&- 3<&-
    echo "Port 8080 is already in use." >&2
    echo "A previous run may have left a server behind: pkill -f server_start.dart" >&2
    return 1
  fi
  return 0
}

# The compose service declares a healthcheck, so readiness is a fact Docker
# reports rather than something to guess at with sleeps.
wait_db_healthy() {
  local tries=60
  log "Waiting for todo-db to become healthy"
  while [ "$tries" -gt 0 ]; do
    if [ "$(docker inspect -f '{{.State.Health.Status}}' todo-db 2>/dev/null)" = "healthy" ]; then
      return 0
    fi
    sleep 2
    tries=$((tries - 1))
  done
  echo "todo-db did not become healthy in time." >&2
  docker logs todo-db 2>&1 | tail -40 >&2
  return 1
}

# `|| true` is load-bearing under `set -e`: while the server is still booting
# curl exits 7 on connection-refused, and a bare assignment from a command
# substitution takes that status, which would abort the run on the first poll.
# curl has already written the "000" sentinel via `-w`, and `true` prints
# nothing, so `$code` keeps the value the loop is testing for. Do not "fix" this
# to `|| echo 000` — that appends a second sentinel ("000000"), which reads as
# up while the server is still down.
#
# The budget is generous because `dart run` cold-compiles the whole
# `tom_core_server` graph on a stale package cache; the boot itself is fast.
wait_server_up() {
  local tries=180 code
  log "Waiting for the server (http://localhost:8080/health)"
  while [ "$tries" -gt 0 ]; do
    code="$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/health 2>/dev/null || true)"
    [ "$code" = "200" ] && return 0
    sleep 2
    tries=$((tries - 1))
  done
  echo "The server did not start in time (last status: '${code:-none}')." >&2
  return 1
}

# The whole point of the runner. The live suite is written to skip when it
# cannot reach the server, which `dart test` reports as success; here the stack
# is known good, so a skip means it stopped being good between the health check
# and the request. That is a failure, and silently reporting it as a pass is the
# exact blind spot this script was written to close.
run_live_suite() {
  local output status
  log "Running the live endpoint suite"
  set +e
  output="$(cd "$SAMPLE_DIR" && dart test test/todo_endpoints_integration_test.dart 2>&1)"
  status=$?
  set -e
  printf '%s\n' "$output"

  if [ "$status" -eq 0 ] && printf '%s' "$output" | grep -q 'All tests skipped'; then
    echo "The live suite was SKIPPED (server unreachable at test time) — treating as failure." >&2
    status=1
  fi
  return "$status"
}

# 0. Preflight.
assert_server_port_free

# 1. Fresh database. `down -v` drops the volume so the initdb hook replays the
#    migration tree, seeding the rows and grants the live suite asserts.
log "Starting the database (fresh volume)"
(cd "$SAMPLE_DIR" && docker compose down -v >/dev/null 2>&1; docker compose up -d db)
wait_db_healthy

# 2. Resolve dependencies before anything is timed.
log "Resolving Dart dependencies"
(cd "$SAMPLE_DIR" && dart pub get)

# 3. Boot the server from the package root, since the asset and migration paths
#    it loads are relative to the CWD. `--port=8080` is passed explicitly rather
#    than relied upon: it is the documented override, and pinning it here means a
#    stray `port` key in a config overlay cannot move the server out from under
#    the health check below. `exec` makes the subshell *become* the dart process,
#    so the recorded PID is the server itself — killing it in cleanup actually
#    frees the port instead of orphaning a child that fails the next run's
#    preflight.
log "Starting the sample server"
(cd "$SAMPLE_DIR" && exec dart run bin/server_start.dart --port=8080 \
  >"$LOG_DIR/server.log" 2>&1) &
SERVER_PID=$!
wait_server_up

# 4. The live proof.
result=0
run_live_suite || result=1

# 5. The connection-free half, run in the same breath so that one command
#    verifies the whole package. Enumerated by glob rather than listed, so a new
#    unit suite is picked up without editing this script; the live suite is
#    excluded by name because step 4 already ran it under the skip-is-failure
#    rule, and running it twice would only add a second chance to be misread.
#
#    Run even when step 4 failed: when a change breaks both, seeing both in one
#    run beats fixing them a boot at a time.
for suite in "$SAMPLE_DIR"/test/*_test.dart; do
  case "$(basename "$suite")" in
    todo_endpoints_integration_test.dart) continue ;;
  esac
  log "Running $(basename "$suite")"
  (cd "$SAMPLE_DIR" && dart test "test/$(basename "$suite")") || result=1
done

# 6. The example is a headless smoke test that exits non-zero on any failed
#    expectation, so it belongs in the gate rather than beside it — a sample
#    whose advertised walkthrough has stopped working is broken even when every
#    test passes.
log "Running the database-free example"
(cd "$SAMPLE_DIR" && dart run example/run_all_examples.dart) || result=1

if [ "$result" -eq 0 ]; then
  log "core_server_sample verified end-to-end"
fi

exit "$result"
