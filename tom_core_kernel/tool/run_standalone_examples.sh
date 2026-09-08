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
# It also checks the reader's side of (a), on two counts of its own: every
# sample must contain at least one `assert` — a sample with none exits 0
# whatever the API does, and so proves nothing about what it demonstrates — and
# every sample's `main()` must open with `prepareSampleProcess()` (or
# `bootstrapSamples()`, which calls it), so a flagless run refuses instead of
# reporting a success it did not verify.
#
# And two checks about the output rather than the run. Every sample must open
# `run()` with `print('=== NN: Title ===\n')` carrying its own file number, so
# that a reader watching a group runner's single continuous stream can tell
# which file each block came from. A sample that prints nothing contributes no
# block at all; one that opens with a heading of its own devising, or with
# somebody else's number, contributes a block filed under the wrong name.
#
# That much is visible in the source, so it is checked there. Whether the banner
# is *reached* is not: a banner in `main()` names the sample on this sweep's
# standalone path and leaves it anonymous in the group runner, which calls
# `run()`. So the group runners' own logs are read after the sweep, and every
# sample must appear in its group's stream. Two checks, because they answer two
# different questions and each passes while the other fails.
#
# Exits non-zero if any sample fails, any documented command omits the flag or
# names a file that does not exist, any sample verifies nothing — either by
# asserting nothing, or by running hollow without the flag — or any sample does
# not name itself, in its source or in its group's stream.

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
# or gitignored, so nothing in them is documentation. And this script excludes
# *itself*: the prose above describing the check matches the pattern the check
# looks for, and a guard that always reports itself reports nothing.
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
# `prepareSampleProcess()` — or with `bootstrapSamples()`, which calls it —
# and this checks that it does.
#
# Checked statically rather than by running each sample twice: the flagless run
# is another 115 VM starts for a property that is visible in the source. The
# point is to catch the *next* sample, written by someone who did not know the
# convention, on the first sweep after they add it.
#
# A sample with no `assert` at all has no verification for a missing flag to
# strip, so it is skipped here and caught by the check below instead.
unguarded=()
while IFS= read -r file; do
  grep -q 'assert(' "$file" || continue
  grep -qE '(prepareSampleProcess|bootstrapSamples)\(\)' "$file" && continue
  unguarded+=("$file")
done < <(find example/samples -name '[0-9][0-9]_*.dart' | sort; echo example/run_all_samples.dart)

if [ ${#unguarded[@]} -gt 0 ]; then
  echo "Samples whose main() never calls prepareSampleProcess() (${#unguarded[@]}):"
  printf '    %s\n' "${unguarded[@]}"
  echo
fi

# The gap the check above leaves open, and the more serious of the two: a sample
# with no `assert` anywhere. It prints its output and exits 0 whatever the API
# does, so it proves nothing about what it demonstrates — and it slips past the
# guard check as well, because there is no verification for a missing flag to
# strip. One such sample existed (`beanlocator/05`) and stayed green under every
# check in this script for as long as it did.
#
# `00_run_all_examples.dart` and `example/run_all_samples.dart` are excluded by
# name: a group runner delegates to samples that assert and correctly has none
# of its own.
unverified=()
while IFS= read -r file; do
  case "${file##*/}" in 00_run_all_examples.dart) continue ;; esac
  grep -q 'assert(' "$file" && continue
  unverified+=("$file")
done < <(find example/samples -name '[0-9][0-9]_*.dart' | sort)

if [ ${#unverified[@]} -gt 0 ]; then
  echo "Samples containing no assert at all (${#unverified[@]}):"
  printf '    %s\n' "${unverified[@]}"
  echo
fi

# Whether a sample says which sample it is.
#
# The checks above are about a sample running honestly. This one is about the
# reader being able to tell which one just ran. `00_run_all_examples.dart` runs
# a whole group back to back, so its output is one long stream, and the only
# thing separating one sample's contribution from the next is what the samples
# themselves print. Twenty-seven of them printed nothing at all — they ran,
# asserted, exited 0 and left no trace in the stream, so a reader watching it
# could not have told they were there. Another eighteen printed freely but
# opened with no heading, or with a heading in a shape of their own, so their
# output arrived attached to whichever sample had last named itself.
#
# So every sample opens `run()` with its own banner, carrying the number it is
# filed under:
#
#     print('=== 03: Resource Fallback Example ===\n');
#
# Both halves are checked, because both fail. A missing banner is the obvious
# one. A banner whose number disagrees with the filename is the worse one: it
# reads as an answer, and it sends a reader who wants the source to the wrong
# file. That arrives by copying a neighbouring sample as a starting point and
# editing everything except the number — which is exactly how samples get
# written.
#
# Checked statically, and against the filename rather than against a list: a
# list is a second place to update, and the number is already on the file.
# Group runners are excluded by name — a runner is not a sample, and the samples
# it delegates to name themselves. For the same reason a runner must not print a
# per-file heading of its own: that is a second title for one file, and ten
# runners carried one until five of them had drifted out of step with the
# sample they introduced.
unattributable=()
while IFS= read -r file; do
  case "${file##*/}" in 00_run_all_examples.dart) continue ;; esac
  name="${file##*/}"
  banner=$(grep -oE "print\('=== [0-9]{2}: [^']*'\);" "$file" | head -1)
  if [ -z "$banner" ]; then
    unattributable+=("$file -> no '=== NN: Title ===' banner")
    continue
  fi
  said=$(printf '%s\n' "$banner" | sed -E "s/.*=== ([0-9]{2}):.*/\1/")
  if [ "$said" != "${name:0:2}" ]; then
    unattributable+=("$file -> banner says $said")
  fi
done < <(find example/samples -name '[0-9][0-9]_*.dart' | sort)

if [ ${#unattributable[@]} -gt 0 ]; then
  echo "Samples a reader cannot attribute in a group stream (${#unattributable[@]}):"
  printf '    %s\n' "${unattributable[@]}"
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
# `git mv`; its header is prose in a neighbouring file and stays behind.
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

# The other half of the attribution question, and the half a static check cannot
# answer: whether the banner is *reachable from `run()`*.
#
# The check above reads each sample as text, so it sees a banner anywhere in the
# file. `logging/05` had one in `main()` and nowhere else: it named itself
# perfectly on the standalone path this sweep exercises, and was anonymous inside
# its group runner, which calls `run()` and never `main()`. That is precisely the
# failure the banner exists to prevent, passing the check written to prevent it.
#
# Tightening the static check is the wrong repair. "In `run()`" is not the
# property that matters — `beanlocator/05`'s `run()` is a one-line delegation to
# a class method that holds the banner, and is correct. The property that matters
# is that the banner reaches the stream, and the only honest way to know that is
# to read the stream.
#
# Which the sweep has already produced: `00_run_all_examples.dart` matches the
# sample glob, so every group runner has just run and been logged. So this costs
# a `grep` per sample and no further VM starts.
#
# A group whose runner failed or hung is skipped: its stream stops where it
# stopped, and reporting every sample after that point as anonymous would bury
# the one failure that explains them under a dozen that do not.
anonymous=()
for runner in "${files[@]}"; do
  case "$runner" in */00_run_all_examples.dart) ;; *) continue ;; esac
  log="$LOG_DIR/$(echo "${runner#example/}" | tr '/' '_').log"
  [ -f "$log" ] || continue
  skip=false
  for bad in ${failed[@]+"${failed[@]}"} ${hung[@]+"${hung[@]}"}; do
    [ "$bad" = "$runner" ] && skip=true && break
  done
  $skip && continue
  group="${runner%/00_run_all_examples.dart}"
  while IFS= read -r sample; do
    name="${sample##*/}"
    grep -q "=== ${name:0:2}: " "$log" \
      || anonymous+=("$sample -> banner never reaches ${group#example/samples/} group stream")
  done < <(find "$group" -name '[0-9][0-9]_*.dart' ! -name '00_*' | sort)
done

if [ ${#anonymous[@]} -gt 0 ]; then
  echo "Samples anonymous in their own group's stream (${#anonymous[@]}):"
  printf '    %s\n' "${anonymous[@]}"
  echo
fi

if [ ${#failed[@]} -eq 0 ] && [ ${#hung[@]} -eq 0 ] && [ ${#flagless[@]} -eq 0 ] \
  && [ ${#unguarded[@]} -eq 0 ] && [ ${#unverified[@]} -eq 0 ] \
  && [ ${#unattributable[@]} -eq 0 ] && [ ${#anonymous[@]} -eq 0 ] \
  && [ ${#missing_path[@]} -eq 0 ]; then
  echo "All ${#files[@]} samples ran standalone and exited 0,"
  echo "every documented command names a file that exists and passes"
  echo "--enable-asserts, every sample asserts something, every sample"
  echo "refuses to run without the flag, and every sample names itself"
  echo "with the number it is filed under — in its own group's stream,"
  echo "not merely somewhere in its source."
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
  echo "No prepareSampleProcess() in main() (${#unguarded[@]}):"
  printf '    %s\n' "${unguarded[@]}"
fi
if [ ${#unverified[@]} -gt 0 ]; then
  echo "No assert at all (${#unverified[@]}):"
  printf '    %s\n' "${unverified[@]}"
fi
if [ ${#unattributable[@]} -gt 0 ]; then
  echo "No banner, or a banner carrying the wrong number (${#unattributable[@]}):"
  printf '    %s\n' "${unattributable[@]}"
fi
if [ ${#anonymous[@]} -gt 0 ]; then
  echo "Banner never reaches the group stream (${#anonymous[@]}):"
  printf '    %s\n' "${anonymous[@]}"
fi
if [ ${#missing_path[@]} -gt 0 ]; then
  echo "Documented path does not exist (${#missing_path[@]}):"
  printf '    %s\n' "${missing_path[@]}"
fi
echo "Logs: $LOG_DIR"
exit 1
