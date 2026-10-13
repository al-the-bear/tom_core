#!/usr/bin/env bash
#
# Runs the single sign-on interoperability suite against a throwaway Keycloak.
#
# `test/sso_keycloak_test.dart` (tag `sso`) logs in over OpenID Connect and over
# SAML 2.0 against a real identity provider, and self-skips when none is
# reachable, so the default `testkit :test` run stays green everywhere. This
# script provides the provider: it boots the bundled `docker-compose.sso.yaml`
# Keycloak on host port 8089 with the realm in `test/fixtures/keycloak/`, waits
# until the realm answers, runs the SSO-tagged tests against it, and tears it
# down again.
#
#   tom_core_server/tool/run_sso_tests.sh
#
# Requirements: docker (+ compose v2), curl and the Dart SDK on PATH. Host port
# 8089 must be free. Keycloak starts from a fresh container each run.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.sso.yaml"
REALM_URL="http://127.0.0.1:${TOM_CORE_SERVER_SSO_PORT:-8089}/realms/tom/.well-known/openid-configuration"

log() { printf '\n=== %s ===\n' "$*"; }

cleanup() {
  log "Tearing down Keycloak"
  (cd "$PROJECT_DIR" && docker compose -f "$COMPOSE_FILE" down -v) >/dev/null 2>&1 || true
}
trap cleanup EXIT

log "Starting Keycloak (docker-compose.sso.yaml, port ${TOM_CORE_SERVER_SSO_PORT:-8089})"
(cd "$PROJECT_DIR" && docker compose -f "$COMPOSE_FILE" up -d)

log "Waiting for the realm to answer"
tries=90
until curl -sf "$REALM_URL" >/dev/null; do
  tries=$((tries - 1))
  if [ "$tries" -eq 0 ]; then
    echo "Keycloak did not serve the realm in time." >&2
    exit 1
  fi
  sleep 2
done

log "Running SSO-tagged tests"
cd "$PROJECT_DIR"
dart test --tags sso
