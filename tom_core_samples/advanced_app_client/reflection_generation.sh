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
# `dart` from PATH, falling back to the fleet's Linux Flutter SDK location. The
# absolute path alone made the script runnable on exactly one host.
if command -v dart >/dev/null 2>&1; then
  DART=dart
else
  DART=/srv/flutter/flutter/bin/dart
fi
"$DART" run tom_reflection_generator "$@"
