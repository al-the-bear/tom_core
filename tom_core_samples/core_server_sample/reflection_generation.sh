#!/usr/bin/env bash
# Regenerate bin/server_start.reflection.dart (the reflection metadata the live
# server boot needs: config class, endpoint service, persistence records, and
# the transitively-reached MariaDB driver/migrator/grant types). The reflection
# root is bin/server_start.dart, configured in build.yaml.
#
# Runs flag-free: the generator scans the current project only (framework
# default scan '.', non-recursive), so no --nested and no workspace registry
# are needed.
#
# Run from the project root:
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
