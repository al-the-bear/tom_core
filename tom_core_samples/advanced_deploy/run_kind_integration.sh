#!/usr/bin/env bash
#
# Deploys the advanced sample to a local kind cluster from the production
# templates beside this script, and runs the sample's integration suites
# against the cluster.
#
#   tom_core_samples/advanced_deploy/run_kind_integration.sh [--keep]
#
# What it does, in order:
#
#  1. creates a fresh kind cluster `tom-advanced` (kind-cluster.yaml), which
#     maps the NodePorts to host ports 8080/8081 (servers) and 3307/3308
#     (databases);
#  2. builds the three server images from the Dockerfile and loads them into
#     the cluster;
#  3. creates the two Secrets the base leaves to the deployment — database
#     passwords and JWT key material — from freshly generated values;
#  4. deploys k8s/overlays/kind: the production configuration (`env: prod`,
#     real keys, no demo data). Every rollout must become ready, which proves
#     the servers boot under prod against empty databases, migrate them, and
#     pass their probes;
#  5. restarts the app server while polling it about ten times a second, and
#     fails if a request was refused: the graceful shutdown and the readiness
#     probe hand traffic over without a gap;
#  6. deploys k8s/overlays/kind-demo (`env: dev`) and restarts the servers, which
#     apply the demo seed the suites sign in as;
#  7. runs the cross-tier integration run and the ops live suites against the
#     cluster (`--external-stack`, `--external-databases`);
#  8. deletes the cluster, unless `--keep` is given.
#
# Requirements: docker, kind, kubectl, openssl and the Dart SDK on PATH; host
# ports 8080, 8081, 3307 and 3308 free.
set -euo pipefail

KEEP=0
for arg in "$@"; do
  case "$arg" in
    --keep) KEEP=1 ;;
    *) echo "Unknown argument: $arg" >&2; exit 64 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAMPLES="$(cd "$SCRIPT_DIR/.." && pwd)"
# The build context: the directory holding core/, reflection/ and
# core_extension/, which the servers' path dependencies reach.
CONTEXT="$(cd "$SAMPLES/../.." && pwd)"
CLUSTER=tom-advanced
CONTEXT_NAME="kind-$CLUSTER"
NAMESPACE=tom-advanced
SECRETS_DIR="$(mktemp -d)"

log() { printf '\n=== %s ===\n' "$*"; }
kc() { kubectl --context "$CONTEXT_NAME" -n "$NAMESPACE" "$@"; }

cleanup() {
  local exit_code=$?
  set +e
  if [ "$exit_code" -ne 0 ] && kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
    log "Cluster state at failure"
    kc get pods -o wide
    for deployment in auth-server app-server ops-server; do
      echo "--- $deployment ---"
      kc logs "deployment/$deployment" --tail=60 --all-containers 2>/dev/null
    done
  fi
  rm -rf "$SECRETS_DIR"
  if [ "$KEEP" -eq 1 ]; then
    log "Keeping cluster $CLUSTER (kind delete cluster --name $CLUSTER)"
  else
    log "Deleting cluster $CLUSTER"
    kind delete cluster --name "$CLUSTER" >/dev/null 2>&1
  fi
}

for tool in docker kind kubectl openssl dart; do
  command -v "$tool" >/dev/null || { echo "$tool is not on PATH." >&2; exit 1; }
done

log "Checking host ports 8080, 8081, 3307, 3308 are free"
for port in 8080 8081 3307 3308; do
  if (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; then
    echo "Host port $port is in use; the cluster maps it." >&2
    exit 1
  fi
done

trap cleanup EXIT

# 1. A fresh cluster: the suites need databases in their seeded state.
log "Creating kind cluster $CLUSTER"
kind delete cluster --name "$CLUSTER" >/dev/null 2>&1 || true
kind create cluster --config "$SCRIPT_DIR/kind-cluster.yaml" --wait 120s

# 2. The images, built once and loaded into the node (never pulled).
build_image() {
  local name="$1" package="$2" entry="$3"
  log "Building $name:local"
  DOCKER_BUILDKIT=1 docker build \
    -f "$SCRIPT_DIR/Dockerfile" \
    --build-arg "PACKAGE=$package" \
    --build-arg "ENTRY=$entry" \
    -t "$name:local" "$CONTEXT"
  kind load docker-image "$name:local" --name "$CLUSTER"
}
build_image advanced-auth-server advanced_auth_server bin/auth_server_start.dart
build_image advanced-app-server advanced_app_server bin/app_server_start.dart
build_image advanced-ops-server advanced_ops_server bin/ops_server_start.dart

# 3. The Secrets the base references and does not ship.
log "Creating secrets from fresh key material"
kubectl --context "$CONTEXT_NAME" apply -f "$SCRIPT_DIR/k8s/base/namespace.yaml"
password() { openssl rand -hex 16; }
AUTH_DB_PASSWORD="$(password)"
APP_DB_PASSWORD="$(password)"
kc create secret generic advanced-db-credentials \
  --from-literal=auth-password="$AUTH_DB_PASSWORD" \
  --from-literal=auth-root-password="$(password)" \
  --from-literal=app-password="$APP_DB_PASSWORD" \
  --from-literal=app-root-password="$(password)"
# The signing pair: the auth server holds the private key, the app server
# verifies with the public one. The payload pair encrypts the access-control
# section of a token; both servers hold both halves.
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 \
  -out "$SECRETS_DIR/signing-private.pem" 2>/dev/null
openssl pkey -in "$SECRETS_DIR/signing-private.pem" -pubout \
  -out "$SECRETS_DIR/signing-public.pem"
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 \
  -out "$SECRETS_DIR/payload-private.pem" 2>/dev/null
openssl pkey -in "$SECRETS_DIR/payload-private.pem" -pubout \
  -out "$SECRETS_DIR/payload-public.pem"
kc create secret generic advanced-jwt-keys \
  --from-file="$SECRETS_DIR/signing-private.pem" \
  --from-file="$SECRETS_DIR/signing-public.pem" \
  --from-file="$SECRETS_DIR/payload-private.pem" \
  --from-file="$SECRETS_DIR/payload-public.pem"

wait_rollouts() {
  local workload
  for workload in statefulset/auth-db statefulset/app-db \
    deployment/auth-server deployment/app-server deployment/ops-server; do
    kc rollout status "$workload" --timeout=300s
  done
}

# 4. Production first: the template as it ships, on empty databases.
log "Deploying the production configuration (overlays/kind, env: prod)"
kubectl --context "$CONTEXT_NAME" apply -k "$SCRIPT_DIR/k8s/overlays/kind"
wait_rollouts

# 5. A rolling restart must not refuse a request.
log "Restarting the app server under load"
# A poller asks /health about ten times a second for the whole restart and
# records every answer; the restart waits on its own.
POLL_LOG="$SECRETS_DIR/restart_poll.log"
(
  while :; do
    curl -s -o /dev/null -m 2 -w '%{http_code}\n' http://localhost:8080/health \
      >>"$POLL_LOG" 2>/dev/null || echo "000" >>"$POLL_LOG"
    sleep 0.1
  done
) &
POLLER=$!
kc rollout restart deployment/app-server
kc rollout status deployment/app-server --timeout=300s
# The old pods are still draining after the rollout reports done; poll on
# until they are gone.
for _ in $(seq 60); do
  [ "$(kc get pods -l app.kubernetes.io/name=app-server --no-headers | wc -l)" -le 2 ] && break
  sleep 1
done
sleep 2
kill "$POLLER"
wait "$POLLER" 2>/dev/null || true
served="$(grep -c '^200$' "$POLL_LOG" || true)"
refused="$(grep -vc '^200$' "$POLL_LOG" || true)"
echo "  $served requests served, $refused refused during the rolling restart"
if [ "$refused" -ne 0 ]; then
  grep -v '^200$' "$POLL_LOG" | sort | uniq -c
  echo "The rolling restart refused requests." >&2
  exit 1
fi

# 6. The demo seed the suites sign in as. The ConfigMap change reaches the pods
#    only through a restart.
log "Deploying the demo data (overlays/kind-demo, env: dev)"
kubectl --context "$CONTEXT_NAME" apply -k "$SCRIPT_DIR/k8s/overlays/kind-demo"
kc rollout restart deployment/auth-server deployment/app-server deployment/ops-server
wait_rollouts

# 7. The suites, against the cluster.
result=0
log "Running the cross-tier integration run against the cluster"
"$SAMPLES/advanced_client_core/tool/run_cross_tier_integration.sh" --external-stack || result=1
log "Running the ops live suites against the cluster's databases"
APP_DB_PASSWORD="$APP_DB_PASSWORD" AUTH_DB_PASSWORD="$AUTH_DB_PASSWORD" \
  "$SAMPLES/advanced_ops_server/tool/run_ops_integration.sh" --external-databases || result=1

if [ "$result" -eq 0 ]; then
  log "All suites passed against the cluster"
fi
exit "$result"
