#!/usr/bin/env bash
# Regenerate this project's reflection metadata — without it,
# ClassMirror/InstanceMirror construction throws "Reflection has not been
# initialized". Two roots, both configured in build.yaml:
#
#   test/fixtures/reflection_fixture.dart
#     → test/fixtures/reflection_fixture.reflection.dart, for the test suite.
#   example/scheduling/cluster/cluster_reflection.dart
#     → example/scheduling/cluster/cluster_reflection.reflection.dart, for the
#       two-node cluster demonstration, which runs as standalone processes and
#       so cannot borrow the test fixture's.
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
