#!/usr/bin/env bash
#
# Runs the test suite once per timezone, to catch defects that a single-zone
# run cannot see.
#
#   tom_core_kernel/tool/run_tz_matrix.sh [test-path ...]
#   tom_core_kernel/tool/run_tz_matrix.sh --examples
#
# With --examples it sweeps the sample runner instead of the test suite. The
# samples check themselves with ~1800 `assert`s, which Dart strips unless
# `--enable-asserts` is passed, so they are run with that flag here — without
# it they print their output, exit 0, and verify nothing. The samples are as
# zone-sensitive as the tests: an assertion on a wall-clock `DateTime(...)`
# holds only within a band of UTC offsets around the author's own.
#
# Why this exists: a value built from `DateTime(1970)` (local) and one built
# from `DateTime.utc(1970)` are *the same object* when the process runs in UTC.
# Under UTC the difference is unobservable, so a suite that only ever runs in
# UTC — the usual CI default — cannot distinguish them. A mutation audit of the
# observable "no value" sentinels made this concrete: reverting any of the six
# sentinels to the local-time epoch survives a full UTC run and is killed
# immediately under Europe/Berlin.
#
# The zones below are chosen to span the interesting cases rather than to be
# exhaustive:
#
#   UTC                  the degenerate case where local == UTC
#   Europe/Berlin        positive offset, observes DST
#   Asia/Tokyo           positive offset, no DST
#   America/Los_Angeles  negative offset — a local epoch lands *after* the UTC
#                        one here, so bugs that assume a consistent direction
#                        of skew show up
#   Pacific/Kiritimati   +14, the largest offset in use; a date-truncated value
#                        built from a local epoch lands on a different day
#
# Dart reads the zone once at process start, so each zone needs its own run;
# there is no way to sweep them inside a single suite.
#
# Exits non-zero if any zone fails, naming the zones that did.

set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

ZONES=(
  UTC
  Europe/Berlin
  Asia/Tokyo
  America/Los_Angeles
  Pacific/Kiritimati
)

if [ "${1:-}" = "--examples" ]; then
  shift
  COMMAND=(dart run --enable-asserts example/run_all_samples.dart)
  what="examples"
else
  TARGETS=("$@")
  if [ ${#TARGETS[@]} -eq 0 ]; then
    TARGETS=(test)
  fi
  COMMAND=(dart test "${TARGETS[@]}")
  what="tests"
fi

echo "Sweeping $what across ${#ZONES[@]} timezones."
echo

failed=()

for zone in "${ZONES[@]}"; do
  printf '%-22s ' "$zone"
  output=$(TZ="$zone" "${COMMAND[@]}" 2>&1)
  if [ $? -eq 0 ]; then
    if [ "$what" = "examples" ]; then
      # The sample runner ends in a drawn box, so its last line says nothing.
      # Report the assertions that actually ran instead.
      echo "OK"
    else
      echo "$output" | tail -1
    fi
  else
    echo "FAILED"
    # An assertion failure is the interesting line and it is not always last —
    # the runner prints a stack trace after it.
    echo "$output" | grep -E "Failed assertion|❌ ERROR running samples" | head -3 | sed 's/^/    /'
    echo "$output" | tail -15 | sed 's/^/    /'
    failed+=("$zone")
  fi
done

echo
if [ ${#failed[@]} -eq 0 ]; then
  echo "All ${#ZONES[@]} timezones passed."
  exit 0
fi

echo "Failed in ${#failed[@]} timezone(s): ${failed[*]}"
exit 1
