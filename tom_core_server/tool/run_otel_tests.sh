#!/usr/bin/env bash
# Runs the `otel` suite (test/metrics_otel_test.dart, test/tracing_otel_test.dart):
# the Prometheus scrape is linted by promtool, and OTLP exports of metrics and
# of spans are sent to an OpenTelemetry Collector whose file exporters write
# back what it received. Starts the collector,
# waits for it, runs `dart test --tags otel`, removes it. A run in which every
# test skipped is a failure, not a pass.
set -euo pipefail
cd "$(dirname "$0")/.."
NAME=tom-core-server-otel-test
PORT="${OTLP_TEST_PORT:-14318}"
COLLECTOR="${OTEL_COLLECTOR_IMAGE:-otel/opentelemetry-collector-contrib:0.111.0}"
PROMTOOL="${PROMTOOL_IMAGE:-prom/prometheus:v2.54.1}"
OUT="$PWD/.dart_tool/otel_test_out"
rm -rf "$OUT" && mkdir -p "$OUT" && chmod 777 "$OUT"
docker rm -f "$NAME" >/dev/null 2>&1 || true
docker pull -q "$PROMTOOL" >/dev/null
docker run -d --name "$NAME" -p "127.0.0.1:$PORT:4318" \
  -v "$PWD/tool/otel/collector.yaml:/etc/otelcol-contrib/config.yaml:ro" \
  -v "$OUT:/out" "$COLLECTOR" >/dev/null
trap 'docker rm -f "$NAME" >/dev/null 2>&1 || true' EXIT
for _ in $(seq 1 60); do
  # The receiver answers 405 to a GET once it is listening.
  code="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/v1/metrics" || true)"
  [ "$code" != "000" ] && break
  sleep 1
done
output="$(TOM_OTLP_TEST_ENDPOINT="http://127.0.0.1:$PORT" \
  TOM_OTLP_TEST_OUTPUT="$OUT/metrics.json" \
  TOM_OTLP_TEST_TRACES_OUTPUT="$OUT/traces.json" \
  TOM_PROMTOOL_IMAGE="$PROMTOOL" \
  dart test --tags otel test/metrics_otel_test.dart test/tracing_otel_test.dart 2>&1)" || { printf '%s\n' "$output"; docker logs "$NAME" 2>&1 | tail -20; exit 1; }
printf '%s\n' "$output"
if printf '%s' "$output" | grep -q 'All tests skipped'; then
  echo "Every otel test skipped: the collector or promtool was not available — treating as failure." >&2
  exit 1
fi
