#!/usr/bin/env bash
# Regenerate lib/reflection_seed.reflection.dart.
# Uses build.yaml config (targets lib/reflection_seed.dart).
#
# Scans the current project only (the framework default is scan '.',
# non-recursive), so no --nested and no workspace registry are needed.
#
# Runs with the summary cache ENABLED (the fast path). Do NOT use --no-cache
# here: on a Flutter package it forces full live analysis of the entire
# Flutter closure under the analyzer, which takes 20+ minutes. The historical
# `RangeError ... StringTable` cached-run crash was analyzer summary-format
# skew (old summaries read by a newer analyzer); the cache is now partitioned
# by analyzer major (<tool-cache>/analyzer-cache/<analyzer-major>/), so a new
# analyzer starts from an empty partition and the skew cannot recur. If a
# skewed/corrupt cache is ever suspected, run once with --rebuild-cache.
#
# Run from the project root:
#   ./reflection_generation.sh [--rebuild-cache]
set -e
cd "$(dirname "$0")"
# Resolve the Dart SDK: an explicit $DART wins, otherwise `dart` from PATH.
# Why no baked-in SDK path: the fleet's hosts install Dart in different places,
# so any absolute default is wrong on most of them and fails with a bare "no
# such file or directory" quoting a path the reader has never seen. Failing
# loudly, with the remedy in the message, is cheaper than guessing.
DART="${DART:-$(command -v dart || true)}"
if [ -z "$DART" ]; then
  echo "reflection_generation.sh: no 'dart' found on PATH." >&2
  echo "  Install the Dart or Flutter SDK and put its bin/ on PATH, or rerun as:" >&2
  echo "    DART=/path/to/dart $0" >&2
  exit 1
fi
"$DART" run tom_reflection_generator "$@"
