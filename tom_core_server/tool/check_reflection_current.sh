#!/usr/bin/env bash
#
# Answers "is the checked-in reflection metadata current?" exactly.
#
# The generated `*.reflection.dart` files are committed, so the file in git is
# the one the suite and the examples load. Nothing in Dart couples them to their
# roots: adding a reflected class or an entity column and not regenerating
# leaves a tree that compiles and analyzes clean, and fails only later at a
# mirror lookup — with "Reflection has not been initialized" or a null member,
# from a place that names neither the class nor the file.
#
# This script settles the question by doing the only thing that can: it
# regenerates and compares. It is exact where `test/reflection_currency_test.dart`
# is only fast — that test checks that recently added *names* appear, which
# catches the mistake people actually make, but cannot see the dense member
# indices (see doc/reflection_generation.md).
#
#   tom_core_server/tool/check_reflection_current.sh
#
# Exit 0: the two generated files are byte-identical to a fresh generation.
# Exit 1: they differ — regenerate and commit, or the graph is mid-edit.
# Exit 2: the working tree already had uncommitted changes to a generated file,
#         so this check cannot attribute a difference to staleness.
#
# Why this is not a test: a run takes two to four minutes against the whole
# package graph, which is longer than the unit suite's entire wall time. Paying
# that on every unrelated change would get the suite skipped. Run this before
# publishing, and after any change to a reflected root.
#
# The working tree is left as it was found: on failure the regenerated files are
# reverted, so a red run does not silently commit itself.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

GENERATED=(
  "test/fixtures/reflection_fixture.reflection.dart"
  "example/example_reflection.reflection.dart"
)

# A dirty generated file before we start makes the result unattributable: a
# difference afterwards could be the edit rather than staleness. Say so instead
# of reporting a failure the reader would have to re-diagnose.
dirty="$(git status --porcelain -- "${GENERATED[@]}")"
if [ -n "$dirty" ]; then
  echo "check_reflection_current.sh: generated files already have uncommitted changes:" >&2
  echo "$dirty" >&2
  echo "  Commit or stash them first — otherwise a difference cannot be" >&2
  echo "  attributed to stale metadata." >&2
  exit 2
fi

echo "Regenerating reflection metadata (two to four minutes)..."
./reflection_generation.sh

changed="$(git status --porcelain -- "${GENERATED[@]}")"
if [ -z "$changed" ]; then
  echo "Reflection metadata is current: regeneration produced no change."
  exit 0
fi

echo "" >&2
echo "check_reflection_current.sh: the checked-in reflection metadata is STALE." >&2
echo "" >&2
echo "Regeneration changed:" >&2
echo "$changed" >&2
echo "" >&2
git --no-pager diff --stat -- "${GENERATED[@]}" >&2
echo "" >&2
echo "  Run ./reflection_generation.sh and commit both generated files." >&2
echo "  A diff of several thousand lines is expected and is not churn — see" >&2
echo "  doc/reflection_generation.md for why one added member renumbers many." >&2

# Leave the tree as found, so a failing check is never mistaken for the fix.
git checkout -- "${GENERATED[@]}"
exit 1
