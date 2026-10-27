#!/usr/bin/env bash
#
# Boots the whole advanced sample stack — both MariaDB databases (via each
# server's docker-compose) and both Dart servers — then runs every live suite in
# this package against it and tears everything down again.
#
# One scripted command for the whole cross-tier scenario: an admin grant edit
# reaching the end-user's field matrix, a share revealing a project to a second
# user, and the same admin edit reaching the file endpoint — one grant cell
# deciding whether bytes may be written. The share is then followed into the
# item's *child collections*: an owner's comment read back by the shared-with
# user, who appends a checklist step the viewer on the same project is refused.
# It also carries the enrolment loop: a second factor enrolled mid-run, declined
# once, and then challenged on the next login.
#
#   tom_core_samples/advanced_client_core/tool/run_cross_tier_integration.sh
#
# Requirements: docker (+ compose v2) and the Dart SDK on PATH. Host ports
# 3307/3308 (databases) and 8080/8081 (servers) must be free. The databases
# start from a *fresh* volume each run (`docker compose down -v`), so the
# initdb seed re-applies and the scenario sees the known seeded state.
#
#   run_cross_tier_integration.sh --external-stack
#
# runs the same suites against a stack that is already up on those ports —
# the sample deployed to a cluster (advanced_deploy/run_kind_integration.sh) —
# and starts and stops nothing. The stack must hold the `dev` seed and be
# fresh: the scenarios change grants and shares as they go.
#
#   run_cross_tier_integration.sh --trace
#
# also starts the local OpenTelemetry Collector of advanced_deploy/otel and runs
# both servers with tracing on, exporting to it (TRACING=true, OTLP_ENDPOINT).
# After the suites it reads what the collector received and fails unless each
# server exported request spans named after their routes, and the app server
# the SQL statements under them. Host port 4318 (OTEL_COLLECTOR_PORT) must be
# free. Not combinable with --external-stack, whose servers this run does not
# configure.
set -euo pipefail

EXTERNAL_STACK=0
TRACE=0
for arg in "$@"; do
  case "$arg" in
    --external-stack) EXTERNAL_STACK=1 ;;
    --trace) TRACE=1 ;;
    *) echo "Unknown argument: $arg" >&2; exit 64 ;;
  esac
done
if [ "$EXTERNAL_STACK" -eq 1 ] && [ "$TRACE" -eq 1 ]; then
  echo "--trace configures the servers this run starts; it cannot be combined with --external-stack." >&2
  exit 64
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_CORE="$(cd "$SCRIPT_DIR/.." && pwd)"
SAMPLES="$(cd "$CLIENT_CORE/.." && pwd)"
AUTH_DIR="$SAMPLES/advanced_auth_server"
APP_DIR="$SAMPLES/advanced_app_server"
OPENAPI_CLIENT="$SAMPLES/advanced_openapi_client"
OTEL_DIR="$SAMPLES/advanced_deploy/otel"
OTEL_PORT="${OTEL_COLLECTOR_PORT:-4318}"

SERVER_PIDS=()
LOG_DIR="$(mktemp -d)"

log() { printf '\n=== %s ===\n' "$*"; }

cleanup() {
  local exit_code=$?
  set +e
  # On any non-zero exit — including a `wait_*` health-check timeout that aborts
  # the run long before the test step — dump whatever the servers logged so the
  # failure is diagnosable. Without this a boot failure tears the stack down and
  # discards the only evidence (the temp LOG_DIR is removed below).
  if [ "$exit_code" -ne 0 ]; then
    [ -s "$LOG_DIR/auth.log" ] && { echo "--- auth server log ---"; cat "$LOG_DIR/auth.log"; }
    [ -s "$LOG_DIR/app.log" ] && { echo "--- app server log ---"; cat "$LOG_DIR/app.log"; }
  fi
  if [ "$EXTERNAL_STACK" -eq 1 ]; then
    rm -rf "$LOG_DIR"
    return
  fi
  log "Tearing down"
  for pid in "${SERVER_PIDS[@]:-}"; do
    [ -n "$pid" ] && kill "$pid" 2>/dev/null
  done
  (cd "$AUTH_DIR" && docker compose down -v) >/dev/null 2>&1
  (cd "$APP_DIR" && docker compose down -v) >/dev/null 2>&1
  if [ "$TRACE" -eq 1 ]; then
    (cd "$OTEL_DIR" && OTEL_COLLECTOR_OUT="$LOG_DIR/otel" docker compose down) >/dev/null 2>&1
  fi
  rm -rf "$LOG_DIR"
}
trap cleanup EXIT

# Fails fast if a leftover *server* is already bound to a host port. Only the
# server ports (8080/8081) are guarded: the database ports (3307/3308) are not,
# because step 1 unconditionally recreates the databases with `down -v` (which
# wipes any stale volume) — a previous run's databases still being up is the
# normal, harmless case, not a hazard. A leftover *server* from an interrupted
# run, by contrast, is never torn down here and would let the stack come up
# against a stale process (or a half-bound socket), turning a real failure into
# a confusing flake — so refuse to start until 8080/8081 are free.
assert_ports_free() {
  log "Checking required server ports (8080/8081) are free"
  local busy=() port
  for port in 8080 8081; do
    if (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; then
      exec 3>&- 3<&-
      busy+=("$port")
    fi
  done
  if [ "${#busy[@]}" -gt 0 ]; then
    echo "Required server port(s) already in use: ${busy[*]}." >&2
    echo "Stop the leftover server holding them (an orphaned dart process from" >&2
    echo "an interrupted run) and re-run." >&2
    return 1
  fi
}

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

# Polls until the app server's public /health returns HTTP 200.
#
# The 180-try (~6 min) budget is deliberately generous: the servers boot with
# `dart run`, which cold-compiles the whole reverse-dependency graph on a stale
# cache (e.g. right after a `tom_core_server` edit) and can take several minutes
# under load. A short budget turns that legitimate one-time compile into a
# spurious "did not answer in time" failure. `precompile_servers` warms the
# cache before the timed waits to keep the common case fast.
wait_app_health() {
  local tries=180
  log "Waiting for app server /health (http://localhost:8080)"
  while [ "$tries" -gt 0 ]; do
    if [ "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/health 2>/dev/null)" = "200" ]; then
      return 0
    fi
    sleep 2
    tries=$((tries - 1))
  done
  echo "App server did not answer /health in time." >&2
  return 1
}

# Polls until the auth server's port answers with a real HTTP status (it has no
# public health endpoint, so any code other than the connection-refused
# sentinel "000" means the socket is serving HTTP — the auth server binds last,
# after migrations/seeding/route mounting, so a 404 on /auth proves it is up).
#
# The `|| true` is load-bearing under `set -e`: while the server is still
# booting, curl gets connection-refused and *exits 7*. A bare
# `code="$(curl …)"` is a simple command whose status is curl's, so `set -e`
# would abort the whole run on the first poll — long before the "000"-means-down
# check below. `|| true` (inside the substitution) swallows only curl's exit
# code; curl has already written the "000" sentinel to stdout via `-w`, and
# `true` prints nothing, so `$code` stays "000" (the down case the loop wants).
#
# Do NOT swap `|| true` for `|| echo 000`: echo would *append* a second "000" →
# "000000", which `!= "000"` reports as up while the server is still booting,
# making the test run against a not-yet-listening auth server and skip. Treat
# both "000" and an empty result (some curl builds print nothing on a failed
# connect) as still-down.
wait_auth_up() {
  local tries=180
  log "Waiting for auth server (http://localhost:8081)"
  while [ "$tries" -gt 0 ]; do
    local code
    code="$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8081/auth 2>/dev/null || true)"
    [ -n "$code" ] && [ "$code" != "000" ] && return 0
    sleep 2
    tries=$((tries - 1))
  done
  echo "Auth server did not start in time." >&2
  return 1
}

if [ "$EXTERNAL_STACK" -eq 1 ]; then
  log "Using the stack already running on 8080/8081"
  (cd "$CLIENT_CORE" && dart pub get)
  (cd "$OPENAPI_CLIENT" && dart pub get)
  wait_auth_up
  wait_app_health
else
# 0. Preflight: refuse to start if a previous run left a port bound.
assert_ports_free

# 1. Fresh databases. `down -v` drops the old volume so the initdb seed re-runs.
log "Starting databases (fresh volumes)"
(cd "$AUTH_DIR" && docker compose down -v >/dev/null 2>&1; docker compose up -d auth-db)
(cd "$APP_DIR" && docker compose down -v >/dev/null 2>&1; docker compose up -d app-db)
wait_db_healthy advanced-auth-db
wait_db_healthy advanced-app-db

# 2. Resolve dependencies once for every package the run touches.
log "Resolving Dart dependencies"
(cd "$AUTH_DIR" && dart pub get)
(cd "$APP_DIR" && dart pub get)
(cd "$CLIENT_CORE" && dart pub get)
(cd "$OPENAPI_CLIENT" && dart pub get)

# 3. Start the auth server first (it owns the grant matrix and mints tokens),
#    then the app server (it reads grants from auth_db and verifies auth tokens).
#    Each runs from its own package root so relative asset/migration paths
#    resolve. `dart run` of the entrypoint source cold-compiles the dependency
#    graph on first boot (covered by the generous `wait_*` budgets above);
#    running a pre-built kernel snapshot instead is *not* viable here — these
#    servers bootstrap generated reflection at startup, which a detached `.dill`
#    fails to initialise. `exec` makes the subshell *become* the dart process,
#    so the recorded PID is the server itself — killing it in cleanup actually
#    stops the server instead of orphaning a dart child that keeps its port
#    bound (and fails the next run's port preflight).
#
#    `env=dev` is passed explicitly rather than left to a `.env` file, because
#    neither package ships one — a reader copies `.env.example` when they want
#    one, and this runner must work whether or not they did. It is not
#    cosmetic: under `prod` both servers refuse to boot, because neither
#    configures its JWT key material — the auth server's `jwtSigningKeyFile`,
#    the app server's `jwtVerificationKeyFiles`, the payload pair both hold —
#    and `installJwtSigning` will not use the framework's bundled sample keys
#    outside a development environment.
#    With --trace, the collector first, and both servers exporting to it.
SERVER_ENV=()
if [ "$TRACE" -eq 1 ]; then
  log "Starting the OpenTelemetry Collector"
  mkdir -p "$LOG_DIR/otel" && chmod 777 "$LOG_DIR/otel"
  (cd "$OTEL_DIR" && OTEL_COLLECTOR_OUT="$LOG_DIR/otel" OTEL_COLLECTOR_PORT="$OTEL_PORT" docker compose up -d)
  for _ in $(seq 1 60); do
    # The receiver answers 405 to a GET once it is listening.
    code="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$OTEL_PORT/v1/traces" || true)"
    [ "$code" != "000" ] && break
    sleep 1
  done
  SERVER_ENV=(TRACING=true "OTLP_ENDPOINT=http://127.0.0.1:$OTEL_PORT")
fi

log "Starting auth server"
(cd "$AUTH_DIR" && exec env ${SERVER_ENV[@]+"${SERVER_ENV[@]}"} dart run bin/auth_server_start.dart env=dev >"$LOG_DIR/auth.log" 2>&1) &
SERVER_PIDS+=($!)
wait_auth_up

log "Starting app server"
(cd "$APP_DIR" && exec env ${SERVER_ENV[@]+"${SERVER_ENV[@]}"} dart run bin/app_server_start.dart env=dev >"$LOG_DIR/app.log" 2>&1) &
SERVER_PIDS+=($!)
wait_app_health
fi

# 4. Run the scripted live scenarios against the stack. Each *skips* (rather
#    than fails) when it cannot reach the servers, so a unit run of the package
#    stays green. Under this runner the servers are guaranteed up, so a skip
#    means something died after the health checks — treat it as a failure and
#    surface the server logs.
#
#    Every `*_integration_test.dart` in the package runs here — five suites,
#    because they prove different things and any can break alone:
#      - cross_tier_integration_test  — the admin→end-user authorization loop:
#        a grant edit reaching the field matrix, a share revealing a project to
#        a second user, and a grant edit reaching the *file endpoint*, where
#        narrowing one `tom_resource_grant` cell takes the upload away from the
#        owner of the row and restoring it gives it back. That beat is what
#        makes file transfer part of this sample's authorization story rather
#        than a feature bolted beside it. It closes on the item's child
#        collections: the owner comments, the shared-with user reads that
#        history back and appends a checklist step, and the viewer on the same
#        project reads the thread but is refused both writes — the
#        one-step-apart gating (`commenter` for a comment, `editor` for a
#        subtask) is only visible when several principals touch one item, so it
#        can only be asserted here.
#      - auth_client_integration_test — the login paths themselves: dave's
#        two-pass TOTP login, and erin's *enrolment* — offered a factor,
#        declining it, setting one up, and then being challenged on the factor
#        she just created. It is the only run in which the real client, the
#        real server and a real secret all take part, so it is the only one
#        that can catch the two halves of the 2FA flow disagreeing on the wire
#        — and the only one where the secret under test is one the server
#        minted mid-run rather than one a migration seeded. It needs no
#        authenticator app: the codes are derived from the enrolment's own
#        `clientData` with the kernel's TomTotp.
#      - file_transfer_integration_test — bytes moving across both servers: an
#        upload landing in each server's own blob store and being served back,
#        the non-exposed file column staying unaddressable, and a principal
#        whose column grade is `read` getting the download while the upload and
#        the delete are refused. Nothing short of a running stack can show a
#        client, an endpoint, a column grade, a blob store and a database
#        agreeing about one file.
#      - app_api_client_integration_test — one end-user call over the wire:
#        health, then alice listing her workspaces through the typed app
#        service client.
#      - admin_api_client_integration_test — the same shape one tier down:
#        admin signing in and listing users through the typed admin client,
#        against the auth server alone.
#
#    One more suite runs from the `advanced_openapi_client` package:
#      - generated_client_integration_test — the clients *generated* from the
#        two servers' OpenAPI documents, which share no code with either server
#        and depend on package:http alone: a login through the generated
#        AuthApi, reads and a write through the generated AppApi carrying its
#        token, the error envelope of an unauthenticated call, and both servers
#        serving the document their client was generated from.
#
#    The app and admin smoke suites are deliberately narrow. The three above them exercise the
#    clients only *through* a scenario, so when one of them breaks it cannot say
#    whether the base URI, the route shape and the DTO decoding stopped agreeing,
#    or whether the authorization logic did. These two answer that question in
#    one line of output — which is worth the two seconds only for as long as
#    something actually runs them.
run_live_suite() {
  local label="$1" path="$2" dir="${3:-$CLIENT_CORE}" output status
  log "Running $label"
  set +e
  output="$(cd "$dir" && dart test "$path" 2>&1)"
  status=$?
  set -e
  printf '%s\n' "$output"

  if [ "$status" -eq 0 ] && printf '%s' "$output" | grep -q 'All tests skipped'; then
    echo "$label was SKIPPED (servers unreachable at test time) — treating as failure." >&2
    status=1
  fi
  return "$status"
}

result=0
run_live_suite "the cross-tier integration test" \
  test/cross_tier_integration_test.dart || result=1
# Run regardless of the previous outcome: when a change breaks both, seeing both
# failures in one run beats fixing them one boot at a time.
run_live_suite "the live auth-client suite (incl. the two-pass 2FA login)" \
  test/auth_client_integration_test.dart || result=1
run_live_suite "the live file-transfer suite (both blob stores, closed column)" \
  test/file_transfer_integration_test.dart || result=1
run_live_suite "the live app API client smoke suite" \
  test/app_api_client_integration_test.dart || result=1
run_live_suite "the live admin API client smoke suite" \
  test/admin_api_client_integration_test.dart || result=1
run_live_suite "the generated OpenAPI clients against both servers" \
  test/generated_client_integration_test.dart "$OPENAPI_CLIENT" || result=1

# 5. With --trace: what the collector received. The servers export a batch
#    every five seconds; waiting for two intervals lets the last suite's spans
#    arrive. Each server must have exported request spans named after their
#    routes, and the app server its SQL statements inside a request's trace.
if [ "$TRACE" -eq 1 ]; then
  log "Checking the spans the collector received"
  sleep 11
  python3 - "$LOG_DIR/otel/traces.json" <<'PY' || result=1
import json, sys
spans = {}
with open(sys.argv[1]) as f:
    for line in f:
        if not line.strip():
            continue
        for rs in json.loads(line).get('resourceSpans', []):
            service = next((a['value'].get('stringValue') for a in rs['resource']['attributes']
                            if a['key'] == 'service.name'), None)
            for ss in rs.get('scopeSpans', []):
                spans.setdefault(service, []).extend(ss.get('spans', []))
def attrs(span):
    return {a['key'] for a in span.get('attributes', [])}
ok = True
for service in ('auth', 'app'):
    found = spans.get(service, [])
    routed = [s for s in found if s.get('kind') == 2 and 'http.route' in attrs(s)]
    sql = [s for s in found if 'db.system.name' in attrs(s)]
    traced_sql = {s['traceId'] for s in sql} & {s['traceId'] for s in routed}
    print(f"{service}: {len(found)} spans, {len(routed)} routed requests, "
          f"{len(sql)} SQL statements, {len(traced_sql)} requests with SQL")
    if not routed or (service == 'app' and not traced_sql):
        print(f"{service}: the expected spans did not arrive", file=sys.stderr)
        ok = False
sys.exit(0 if ok else 1)
PY
fi

# Server logs are dumped by the EXIT trap (cleanup) whenever the run exits
# non-zero, so a test failure here surfaces them without an explicit dump.

exit "$result"
