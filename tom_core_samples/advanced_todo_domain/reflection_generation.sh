#!/usr/bin/env bash
# Regenerate test/run_all_tests.reflection.dart.
# Uses build.yaml config (targets test/run_all_tests.dart).
#
# Runs flag-free: the generator scans the current project only (the framework
# default is scan '.', non-recursive), so no --nested and no workspace registry
# are needed.
#
# Run from the project root:
#   ./reflection_generation.sh
set -e
cd "$(dirname "$0")"
/srv/flutter/flutter/bin/dart run tom_reflection_generator
