#!/usr/bin/env bash
#
# The two-node cluster demonstration.
#
# Brings up MariaDB, applies the shipped scheduler migrations, runs four
# scenarios as pairs of real processes against the one database, and then asks
# `cluster_verify.dart` whether the four claims held. Exits non-zero if any did
# not.
#
#   tom_core_server/example/scheduling/cluster/run_cluster_demo.sh
#
# The four claims, and the process shape each one needs:
#
#   1. SINGLE FIRE   two schedulers, one job, one interval. Every window must be
#                    executed exactly once across the pair, not once each.
#   2. FENCING       a node stalls past its lease without dying; a second takes
#                    over at a higher token; the first wakes and is refused.
#   3. TAKEOVER      a node is `kill -9`ed mid-run. Its work must come back to
#                    the queue after the lease expires — and not before.
#   4. ROLL CALL     a node checks in, then leaves without saying goodbye, and
#                    must be named failed from the one row it always occupied.
#
# Requirements: docker (+ compose v2) and the Dart SDK on PATH. Host port 3309
# must be free, or point the TOM_CORE_SERVER_TEST_DB_* variables elsewhere — the
# same variables the `db`-tagged test suite reads, so a developer who has already
# pointed the suite at a database does not have to point this separately.
#
# The database is recreated from a fresh volume (`down -v`) and the schema is
# dropped and re-migrated by `cluster_provision.dart`, so a run never inherits a
# previous run's leases, queue rows, or roll call.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Every dart command runs from the package root: the migration directory
# `example/scheduling/migrations` is relative to it, and so is `dart run`'s view
# of the package.
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.test.yaml"

EVENTS_DIR="$(mktemp -d)"
NODE_PIDS=()

log() { printf '\n=== %s ===\n' "$*"; }

# Runs one node in the background, capturing its testimony.
#
# Each node gets its own `<phase>_<node>.jsonl`; the verifier reads the whole
# directory. Backgrounding is what makes this a *cluster* demonstration rather
# than two sequential programs — the contention is the subject.
start_node() {
  local phase="$1" node="$2"
  shift 2
  ( cd "$PROJECT_DIR" && exec dart run example/scheduling/cluster/cluster_node.dart \
      "--node=$node" "$@" ) >"$EVENTS_DIR/${phase}_${node}.jsonl" 2>&1 &
  NODE_PIDS+=($!)
}

# Waits for every backgrounded node, failing the run if any exited non-zero.
#
# A node that exits non-zero has failed to *set its scenario up* (it never saw
# its peer, it could not take an uncontended lease). That is a broken experiment,
# not a disproved claim, and it deserves to be distinguished from one.
await_nodes() {
  local pid status=0
  for pid in "${NODE_PIDS[@]:-}"; do
    wait "$pid" || status=1
  done
  NODE_PIDS=()
  if [ "$status" -ne 0 ]; then
    echo "A node exited non-zero; its output follows." >&2
    dump_events
    return 1
  fi
}

dump_events() {
  local file
  for file in "$EVENTS_DIR"/*.jsonl; do
    [ -e "$file" ] || continue
    echo "--- $(basename "$file") ---"
    cat "$file"
  done
}

cleanup() {
  local exit_code=$?
  set +e
  # A failed run's only evidence is these logs, and the temp directory goes with
  # the process. Print them before it does.
  if [ "$exit_code" -ne 0 ]; then
    echo "--- node testimony ---"
    dump_events
  fi
  local pid
  for pid in "${NODE_PIDS[@]:-}"; do
    [ -n "$pid" ] && kill -9 "$pid" 2>/dev/null
  done
  log "Tearing down"
  docker compose -f "$COMPOSE_FILE" down -v >/dev/null 2>&1
  rm -rf "$EVENTS_DIR"
}
trap cleanup EXIT

# -----------------------------------------------------------------------------
# 0. A database, from a clean volume.
# -----------------------------------------------------------------------------
log "Starting MariaDB (fresh volume)"
docker compose -f "$COMPOSE_FILE" down -v >/dev/null 2>&1 || true
docker compose -f "$COMPOSE_FILE" up -d

log "Waiting for MariaDB to become healthy"
tries=60
while [ "$tries" -gt 0 ]; do
  status="$(docker inspect -f '{{.State.Health.Status}}' tom-core-server-test-db 2>/dev/null || echo missing)"
  [ "$status" = "healthy" ] && break
  sleep 2
  tries=$((tries - 1))
done
if [ "$tries" -eq 0 ]; then
  echo "MariaDB did not become healthy in time." >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# 1. Schema, from the shipped migrations, plus the demo's own fenced row.
# -----------------------------------------------------------------------------
log "Resolving dependencies"
(cd "$PROJECT_DIR" && dart pub get >/dev/null)

log "Provisioning the schema"
(cd "$PROJECT_DIR" && dart run example/scheduling/cluster/cluster_provision.dart)

# -----------------------------------------------------------------------------
# 2. SINGLE FIRE — two schedulers, one job, one interval.
# -----------------------------------------------------------------------------
log "Claim 1: one job, two nodes, one execution per window"
start_node steady node-a --scenario=steady --seconds=12 --peer=node-b
start_node steady node-b --scenario=steady --seconds=12 --peer=node-a
await_nodes

# -----------------------------------------------------------------------------
# 3. FENCING — a stall, a takeover, and a refused write from the past.
# -----------------------------------------------------------------------------
#
# The holder starts first and the taker waits (on `lock.inspect`) until it can
# see the lease is held before it starts counting refusals. Without that wait,
# a taker that booted faster than the holder would win the *uncontended* lease
# and quietly invert the scenario into one that proves nothing.
log "Claim 2: a lapsed lease's token no longer authorises a write"
start_node fence node-a --scenario=fence-holder
start_node fence node-b --scenario=fence-taker
await_nodes

# -----------------------------------------------------------------------------
# 4. TAKEOVER — kill -9 mid-run, recovery after the lease and not before.
# -----------------------------------------------------------------------------
#
# `kill -9`, not `kill`: a node given the chance to clean up releases its lease
# and hands its run back, which is an orderly shutdown and a different (easier)
# story. Recovery exists for the node that gets no chance.
log "Claim 3: an abandoned run returns to the queue when its lease expires"
LEASE_TIMEOUT_MS=5000

# Both nodes start together, and the survivor is *already running* when its peer
# dies — which is both the realistic shape and the only one that can time the
# recovery. A survivor booted after the kill spends its first seconds in
# `dart run`'s cold compile, and by the time it asks anything the lease has
# already expired: it would then observe a recovery it could not show was gated
# on the lease rather than merely late.
start_node takeover node-b \
  --scenario=takeover-survivor "--leaseTimeoutMs=$LEASE_TIMEOUT_MS"
( cd "$PROJECT_DIR" && exec dart run example/scheduling/cluster/cluster_node.dart \
    --node=node-a --scenario=takeover-victim ) >"$EVENTS_DIR/takeover_node-a.jsonl" 2>&1 &
VICTIM_PID=$!

# Wait for the victim to have actually claimed and started the run. Killing it
# before that leaves nothing abandoned, and the survivor would wait out its
# patience for a run that was never taken.
tries=300
while [ "$tries" -gt 0 ]; do
  grep -q '"event":"claimed"' "$EVENTS_DIR/takeover_node-a.jsonl" 2>/dev/null && break
  sleep 0.2
  tries=$((tries - 1))
done
if [ "$tries" -eq 0 ]; then
  echo "The takeover victim never claimed the run." >&2
  kill -9 "$VICTIM_PID" 2>/dev/null
  exit 1
fi
kill -9 "$VICTIM_PID" 2>/dev/null
wait "$VICTIM_PID" 2>/dev/null || true

await_nodes

# -----------------------------------------------------------------------------
# 5. ROLL CALL — one row per node, and a name for the one that stopped speaking.
# -----------------------------------------------------------------------------
#
# Fresh node ids (`roll-a` / `roll-b`), so the rows the earlier phases left on
# the roll call cannot be mistaken for this phase's evidence: `node-a` has been
# dead since the takeover and would be declared failed on its own.
log "Claim 4: a node that stops checking in is named, from one row"
start_node rollcall roll-a --scenario=rollcall-quitter --checkins=6 --peer=roll-b
start_node rollcall roll-b --scenario=rollcall-watcher --peer=roll-a
await_nodes

# -----------------------------------------------------------------------------
# 6. The judgement.
# -----------------------------------------------------------------------------
log "Verifying the four claims"
(cd "$PROJECT_DIR" && dart run example/scheduling/cluster/cluster_verify.dart \
    "--events=$EVENTS_DIR")

log "All four claims hold."
