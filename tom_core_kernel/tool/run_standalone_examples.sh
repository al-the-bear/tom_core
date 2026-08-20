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
# Which is also why this script does things that are not runs at all. Before the
# sweep it checks every `dart run …example/…` command the package *documents* —
# anywhere in the package: a sample header, `README.md`, `doc/`, a dartdoc
# comment in `lib/`, a sibling script in `tool/` — on two counts:
#
#   a. it carries `--enable-asserts`. That this sweep passes the flag says
#      nothing about what a reader does, and a reader does what the
#      documentation says. A header that omits it hands out a command under
#      which the sample prints its usual "✓ … passed" and exits 0 while
#      verifying nothing — a green run that proves nothing, which is worse than
#      a red one. The omission is easy to make and invisible once made: nothing
#      about a flagless command looks wrong, and the run it produces looks
#      right. Which is why it is checked rather than watched for.
#
#   b. the path it names exists. The sweep below cannot cover this: it finds
#      samples with `find`, so it runs the files that are there rather than the
#      paths the documentation claims are there. A command naming a moved,
#      renamed or mistyped file is invisible to every other check here and
#      fails immediately for the reader.
#
# It also checks the reader's side of (a): every sample's `main()` must open
# with `requireAsserts()` (or `bootstrapSamples()`, which calls it), so a
# flagless run refuses instead of reporting a success it did not verify.
#
# Exits non-zero if any sample fails, any documented command omits the flag or
# names a file that does not exist, or any sample would run hollow without it.

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

# Every documented command, whichever groups were asked for: a header is wrong
# for every reader, not only for the group under test.
#
# A "documented command" is a `dart run` naming a path under `example/` — which
# is what excludes `dart run build_runner build` (real, and correctly flagless)
# and prose that merely mentions `dart run` without inviting anyone to type it.
#
# The sweep covers the whole package rather than `example/`, `doc/` and
# `README.md`, because a reader does not know which directory a command came
# from: a dartdoc comment in `lib/`, a module `readme.md`, the `CHANGELOG`, a
# sibling script in `tool/` and a note in `_copilot_guidelines/` all hand out a
# command that gets typed. Restricting the search to the three places the
# commands happen to live today would leave the check passing the moment one is
# written anywhere else — which is precisely when it is needed.
#
# Exclusions. `.dart_tool/`, `build/`, `coverage/` and `testlog/` are generated
# or gitignored, so nothing in them is documentation; `doc/analyzer_analysis.json`
# falls out for the same reason via the file-type allowlist, being a generated
# analyzer dump that holds stale copies of dartdoc from before the paths moved.
# And this script excludes *itself*: the prose above describing the check matches
# the pattern the check looks for, and a guard that always reports itself reports
# nothing.
flagless=()
while IFS= read -r hit; do
  [ -n "$hit" ] && flagless+=("$hit")
done < <(grep -rn 'dart run [^`]*example/' \
  --include='*.dart' --include='*.md' --include='*.sh' \
  --include='*.yaml' --include='*.txt' \
  --exclude='run_standalone_examples.sh' \
  --exclude-dir='.dart_tool' --exclude-dir='build' \
  --exclude-dir='coverage' --exclude-dir='testlog' \
  . 2>/dev/null | grep -v -- '--enable-asserts')

if [ ${#flagless[@]} -gt 0 ]; then
  echo "Documented commands missing --enable-asserts (${#flagless[@]}):"
  printf '    %s\n' "${flagless[@]}"
  echo
fi

# The other half of the same problem. Documenting the flag correctly still
# leaves the reader who types the command from memory, or copies it from another
# project, and gets a hollow green. So every sample's `main()` opens with
# `requireAsserts()` — or with `bootstrapSamples()`, which calls it — and this
# checks that it does.
#
# Checked statically rather than by running each sample twice: the flagless run
# is another 115 VM starts for a property that is visible in the source. The
# point is to catch the *next* sample, written by someone who did not know the
# convention, on the first sweep after they add it.
#
# A sample with no `assert` at all is a separate defect and not this one's to
# report — it has no verification for a missing flag to strip.
unguarded=()
while IFS= read -r file; do
  grep -q 'assert(' "$file" || continue
  grep -qE '(requireAsserts|bootstrapSamples)\(\)' "$file" && continue
  unguarded+=("$file")
done < <(find example/samples -name '[0-9][0-9]_*.dart' | sort; echo example/run_all_samples.dart)

if [ ${#unguarded[@]} -gt 0 ]; then
  echo "Samples whose main() never calls requireAsserts() (${#unguarded[@]}):"
  printf '    %s\n' "${unguarded[@]}"
  echo
fi

# A third way a documented command fails the reader, and the one nothing above
# catches: the path it names does not exist.
#
# The two checks above ask whether a command verifies what it runs. Neither asks
# whether it runs at all. Nor does the sweep below, despite running every
# sample: it finds them with `find`, so it exercises the files that *are* there
# rather than the paths the documentation *claims* are there. A header naming a
# moved, renamed or mistyped file therefore passes every check in this script
# and fails for the only person it was written for, with
# "Error when reading '…': No such file or directory".
#
# It is also the failure most likely to arrive unaided. Renaming a sample is a
# `git mv`; its header is prose in a neighbouring file and stays behind. This
# package has already been through one such move — `doc/analyzer_analysis.json`
# still holds dartdoc from before the paths changed, which is why the file-type
# allowlist above leaves it out.
#
# Nothing needs to be run to check this, which is the point: the reader's
# command is a string, and whether the string names a file is answerable
# statically, before the 117 VM starts below.
#
# Trailing punctuation falls out of the character class rather than needing a
# strip — these commands are quoted in prose, and `(dart run … .dart)` occurs.
missing_path=()
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  loc="${hit%%:dart run*}"
  # Every `example/….dart` token in the matched command — normally exactly one,
  # but a line documenting two commands must not have its second one skipped.
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    [ -f "$path" ] && continue
    missing_path+=("$loc -> $path")
  done < <(printf '%s\n' "$hit" | grep -oE 'example/[A-Za-z0-9_./-]*\.dart')
done < <(grep -rno 'dart run [^`]*example/[A-Za-z0-9_./-]*\.dart' \
  --include='*.dart' --include='*.md' --include='*.sh' \
  --include='*.yaml' --include='*.txt' \
  --exclude='run_standalone_examples.sh' \
  --exclude-dir='.dart_tool' --exclude-dir='build' \
  --exclude-dir='coverage' --exclude-dir='testlog' \
  . 2>/dev/null)

if [ ${#missing_path[@]} -gt 0 ]; then
  echo "Documented commands naming a path that does not exist (${#missing_path[@]}):"
  printf '    %s\n' "${missing_path[@]}"
  echo
fi

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
if [ ${#failed[@]} -eq 0 ] && [ ${#hung[@]} -eq 0 ] && [ ${#flagless[@]} -eq 0 ] \
  && [ ${#unguarded[@]} -eq 0 ] && [ ${#missing_path[@]} -eq 0 ]; then
  echo "All ${#files[@]} samples ran standalone and exited 0,"
  echo "every documented command names a file that exists and passes"
  echo "--enable-asserts, and every sample refuses to run without it."
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
# Restated at the end because the check runs before a sweep long enough to
# scroll its own output away.
if [ ${#flagless[@]} -gt 0 ]; then
  echo "Documented without --enable-asserts (${#flagless[@]}):"
  printf '    %s\n' "${flagless[@]}"
fi
if [ ${#unguarded[@]} -gt 0 ]; then
  echo "No requireAsserts() in main() (${#unguarded[@]}):"
  printf '    %s\n' "${unguarded[@]}"
fi
if [ ${#missing_path[@]} -gt 0 ]; then
  echo "Documented path does not exist (${#missing_path[@]}):"
  printf '    %s\n' "${missing_path[@]}"
fi
echo "Logs: $LOG_DIR"
exit 1
