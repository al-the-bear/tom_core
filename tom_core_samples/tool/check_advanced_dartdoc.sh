#!/usr/bin/env bash
#
# Runs `dart doc` over every `advanced_*` package and fails on any warning.
#
#   tom_core_samples/tool/check_advanced_dartdoc.sh
#   tom_core_samples/tool/check_advanced_dartdoc.sh advanced_app_client   # one
#
# ## The question no other check asks
#
# Three different questions can be asked of a `[name]` in a doc comment, and
# they give different answers:
#
#   * *Does this name exist anywhere in the repository?* — `tool/check_dartdoc_refs.py`,
#     deliberately private-name-only, with resolution explicitly out of scope.
#   * *Does this name resolve from the library that writes it?* — the
#     `comment_references` lint, the strictest of the three.
#   * *Does `dart doc` emit a warning?* — this script, and nothing else.
#
# The third is the one that governs whether the generated API pages contain dead
# names, and it sits between the other two rather than being implied by either.
# `dart doc` resolves against a name's **canonical library** (the barrel), not
# the file that declares it, so it accepts references the lint would reject; and
# it rejects some the lint accepts, because a `[Type.member]` reference cannot
# reach an extension member — `[ProjectRole.name]` comes from `dart:core`'s
# `extension EnumName on Enum` and has no page, while its sibling
# `[ProjectRole.viewer]` resolves fine.
#
# Neither guard subsumes the other, which is why this one exists separately.
#
# ## Why a script and not a gate in `tom_ai/core/tool/`
#
# It would belong there — that folder is where this repository keeps its
# documentation invariants, and `check_gates.py` discovers `check_*.py` by glob
# so a gate added there is enforced the day it lands. The obstacle is cost, and
# specifically cost *under that runner*. `dart doc` takes twelve to thirty
# seconds per package, and `check_gates.py` runs each gate as one serial
# subprocess — so eight packages inside a gate is about four minutes, against the
# fifteen seconds the whole python set takes today, and close to the five-minute
# timeout of the suite that runs it. `--dry-run` does not help: the cost is
# analysis, not HTML (measured — 12.6 s dry against ~15 s wet on the smallest
# package).
#
# Documenting the eight in parallel, which is what this script does, brings the
# wall clock to about forty seconds. That is affordable to run by hand and is why
# this is worth having as a runner; it is not something `check_gates.py` can do
# for it, because the parallelism is *within* what would be a single gate.
#
# So it follows the precedent this suite already sets for verification too heavy
# to run on every save: `advanced_client_core/tool/run_cross_tier_integration.sh`
# and `advanced_ops_server/tool/run_ops_integration.sh` are runners for the same
# reason. Run this one after touching a doc comment in the sample suite, and
# before publishing its pages.
#
# ## Zero warnings is necessary, not sufficient
#
# A reference can resolve to *the wrong thing* and say nothing. `[hash]` in
# `advanced_auth_server`'s `password_hashing.dart` — meant as a record field —
# resolved to `vector_math`'s deprecated `hash` library, a transitive dependency
# that package never mentions, and rendered a live link to it. No warning. This
# script cannot see that class of fault; only reading the generated page can.
#
# Requirements: the Dart SDK on PATH. Packages are documented in parallel into a
# scratch directory, which is removed on exit.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAMPLES="$(cd "$SCRIPT_DIR/.." && pwd)"

# Discovered rather than listed: a ninth `advanced_*` package added tomorrow is
# checked tomorrow, rather than whenever someone remembers to extend this line.
if [[ $# -gt 0 ]]; then
  PACKAGES=("$@")
else
  PACKAGES=()
  for dir in "$SAMPLES"/advanced_*/; do
    [[ -f "$dir/pubspec.yaml" ]] && PACKAGES+=("$(basename "$dir")")
  done
fi

if [[ ${#PACKAGES[@]} -eq 0 ]]; then
  echo "no advanced_* package found under $SAMPLES" >&2
  echo "An empty package list must not read as 'everything passes'." >&2
  exit 2
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "Documenting ${#PACKAGES[@]} package(s) with dart doc..."

for package in "${PACKAGES[@]}"; do
  (
    cd "$SAMPLES/$package"
    dart doc --output "$WORK/$package" > "$WORK/$package.log" 2>&1 || true
  ) &
done
wait

failed=0
total=0
for package in "${PACKAGES[@]}"; do
  log="$WORK/$package.log"
  count=$(grep -c "unresolved doc reference" "$log" || true)
  # `dart doc` warns about more than unresolved references; any warning at all
  # means a generated page is wrong, so the pass condition is its own summary
  # line rather than the unresolved-reference count alone.
  if grep -q "^Found 0 warnings and 0 errors\.$" "$log"; then
    printf 'ok    %s\n' "$package"
  else
    failed=$((failed + 1))
    total=$((total + count))
    printf 'FAIL  %s\n' "$package"
    grep -A1 "warning:\|error:" "$log" | sed 's/^/        /' || true
  fi
done

echo
if [[ $failed -eq 0 ]]; then
  echo "${#PACKAGES[@]} package(s), 0 with dart doc warnings"
  exit 0
fi

echo "${#PACKAGES[@]} package(s), $failed with dart doc warnings" \
     "($total unresolved reference(s))"
echo
echo "Repair each reference rather than deleting it. Prefer the fix that keeps a"
echo "working link: qualify a bare member with its owning class"
echo "([member] -> [Class.member], which is what a library-level comment needs"
echo "since it has no enclosing class scope), or add the import when the file"
echo "should have had it anyway. Demote to backticks only when no link is"
echo "reachable — an extension member, a record type's field, a function-type"
echo "parameter, a name declared in bin/ (dartdoc documents lib/ only), or a type"
echo "from a package this one deliberately does not depend on."
exit 1
