#!/usr/bin/env bash
#
# Runs every sample on its own, the way a reader would.
#
#   tom_core_kernel/tool/run_standalone_examples.sh
#   tom_core_kernel/tool/run_standalone_examples.sh observable timezoned
#
# Each sample's header documents `dart run --enable-asserts <file>` as a
# supported way to use it, so that claim needs a guard. `example/run_all_samples.dart`
# is not one: it drives the samples through their group runners, which perform
# setup the samples then inherit, and it ends in `exit(0)`, which force-quits the
# VM. A sample can therefore be green in the master runner and still be broken —
# in three distinct ways, all of which this script catches and the master runner
# cannot:
#
#   1. no `main()`            "Invoked Dart programs must have a 'main' function"
#   2. missing reflection     "Reflection has not been initialized" — the generated
#                             registry is installed by `bootstrapSamples()`, which
#                             a sample must call itself if it builds reflected types
#   3. a non-terminating VM   a `TomShutdownCleanup` whose SIGHUP/SIGINT watchers
#                             were never disposed keeps the process alive forever
#
# The third is why this runs under a watchdog rather than plain `dart run`: the
# failure mode is a hang, not an exit code, and an unattended hang is worse than
# a failure. macOS ships no `timeout(1)`, hence the background-PID pattern.
#
# Asserts are on for the same reason as in run_tz_matrix.sh: the samples check
# themselves with ~1800 `assert`s that Dart strips without the flag, so a run
# without it proves only that nothing threw.
#
# Exits non-zero if any sample fails, naming the samples that did.

set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

# Long enough that a slow cold compile is never mistaken for a hang; short
# enough that a genuine hang does not stall a whole sweep. The slowest sample
# takes a few seconds.
TIMEOUT_SECONDS="${TOM_SAMPLE_TIMEOUT:-60}"

# `testlog/` is the package's gitignored home for run artifacts, so the logs of
# a failing sweep survive for inspection without ever reaching a commit.
LOG_DIR="testlog/standalone_examples"

# Samples are numbered (`03_tom_class.dart`); support libraries beside them are
# not (`scheduling_support.dart`). Keying on the convention keeps this free of
# an exclusion list that would silently rot.
if [ $# -gt 0 ]; then
  files=()
  for group in "$@"; do
    if [ ! -d "example/samples/$group" ]; then
      echo "No such sample group: $group" >&2
      exit 1
    fi
    while IFS= read -r f; do files+=("$f"); done \
      < <(find "example/samples/$group" -name '[0-9][0-9]_*.dart' | sort)
  done
else
  files=()
  while IFS= read -r f; do files+=("$f"); done \
    < <(find example/samples -name '[0-9][0-9]_*.dart' | sort)
  files+=(example/run_all_samples.dart)
fi

if [ ${#files[@]} -eq 0 ]; then
  echo "No samples matched." >&2
  exit 1
fi

mkdir -p "$LOG_DIR"

echo "Running ${#files[@]} samples standalone (timeout ${TIMEOUT_SECONDS}s each)."
echo

failed=()
hung=()

for file in "${files[@]}"; do
  log="$LOG_DIR/$(echo "${file#example/}" | tr '/' '_').log"
  printf '%-62s ' "${file#example/samples/}"

  dart run --enable-asserts "$file" > "$log" 2>&1 &
  pid=$!

  # SIGTERM first so the VM gets a chance to flush its output; SIGKILL only if
  # it ignores that. A `kill -9` alone discards the buffered stdout and leaves
  # an empty log, which is the least useful thing to hand someone debugging.
  ( sleep "$TIMEOUT_SECONDS"; kill -TERM $pid 2>/dev/null; sleep 2; kill -KILL $pid 2>/dev/null ) &
  watchdog=$!

  wait $pid
  status=$?
  kill $watchdog 2>/dev/null
  wait $watchdog 2>/dev/null

  # 143 = SIGTERM, 137 = SIGKILL — both mean the watchdog fired.
  if [ $status -eq 143 ] || [ $status -eq 137 ]; then
    echo "HUNG"
    hung+=("$file")
  elif [ $status -ne 0 ]; then
    echo "FAILED ($status)"
    grep -E "Unhandled exception|Failed assertion|^Error" "$log" | head -2 | sed 's/^/    /'
    failed+=("$file")
  else
    echo "OK"
  fi
done

echo
if [ ${#failed[@]} -eq 0 ] && [ ${#hung[@]} -eq 0 ]; then
  echo "All ${#files[@]} samples ran standalone and exited 0."
  exit 0
fi

if [ ${#hung[@]} -gt 0 ]; then
  echo "Did not terminate within ${TIMEOUT_SECONDS}s (${#hung[@]}):"
  printf '    %s\n' "${hung[@]}"
fi
if [ ${#failed[@]} -gt 0 ]; then
  echo "Failed (${#failed[@]}):"
  printf '    %s\n' "${failed[@]}"
fi
echo "Logs: $LOG_DIR"
exit 1
