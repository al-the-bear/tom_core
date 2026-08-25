#!/usr/bin/env bash
# Regenerate this project's reflection metadata — without it,
# ClassMirror/InstanceMirror construction throws "Reflection has not been
# initialized". Two roots, both configured in build.yaml:
#
#   test/fixtures/reflection_fixture.dart
#     → test/fixtures/reflection_fixture.reflection.dart, for the test suite.
#   example/example_reflection.dart
#     → example/example_reflection.reflection.dart, for every example that
#       needs a reflector — the two-node cluster demonstration and the endpoints
#       example's file slot. One root for all of them: an example cannot borrow
#       the test fixture's, and a second root would generate a further ~1.7 MB
#       capturing the same package barrel.
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
