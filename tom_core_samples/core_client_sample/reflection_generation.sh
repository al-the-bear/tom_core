#!/usr/bin/env bash
# Regenerate lib/reflection_seed.reflection.dart from lib/reflection_seed.dart.
# Runs flag-free: the generator scans the current project only (framework
# default scan '.', non-recursive) and reads build.yaml's generate_for, which
# targets lib/reflection_seed.dart. Run from the project root:
#   ./reflection_generation.sh
set -e
cd "$(dirname "$0")"
# `dart` from PATH, falling back to the fleet's Linux Flutter SDK location. The
# absolute path alone made the script runnable on exactly one host.
if command -v dart >/dev/null 2>&1; then
  DART=dart
else
  DART=/srv/flutter/flutter/bin/dart
fi
"$DART" run tom_reflection_generator
