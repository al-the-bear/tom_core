#!/usr/bin/env bash
# Regenerate lib/reflection_seed.reflection.dart.
# Uses build.yaml config (targets lib/reflection_seed.dart).
#
# Scans the current project only (the framework default is scan '.',
# non-recursive), so no --nested and no workspace registry are needed.
#
# --no-cache is REQUIRED here. This is a Flutter package, and the generator's
# summary-cache resolver path crashes reading the analyzer summary bundles for
# the Flutter closure (`RangeError ... StringTable` — an analyzer summary-format
# skew). On that crash the generator fails silently at `resolveFile`, leaves the
# previous output in place, and STILL exits 0 — so a cached run looks successful
# but regenerates nothing. --no-cache does full live analysis (slower, minutes)
# but resolves the whole closure correctly, capturing the contract DTOs the
# reflected forms don't already anchor.
#
# Run from the project root:
#   ./reflection_generation.sh
set -e
cd "$(dirname "$0")"
/srv/flutter/flutter/bin/dart run tom_reflection_generator --no-cache
