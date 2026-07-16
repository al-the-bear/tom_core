#!/usr/bin/env bash
# Regenerate test/fixtures/reflection_fixture.reflection.dart — the reflection
# metadata the test suite needs so ClassMirror/InstanceMirror construction stops
# throwing "Reflection has not been initialized". The reflection root is
# test/fixtures/reflection_fixture.dart, configured in build.yaml.
#
# Runs flag-free: the generator scans the current project only (framework
# default scan '.', non-recursive), so no --nested and no workspace registry
# are needed.
#
# Run from the project root:
#   ./reflection_generation.sh
set -e
cd "$(dirname "$0")"
/srv/flutter/flutter/bin/dart run tom_reflection_generator
