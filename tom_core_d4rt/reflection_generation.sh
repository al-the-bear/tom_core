#!/usr/bin/env bash
# Regenerate lib/src/demo_persistence/reflection_root.reflection.dart — the
# reflection metadata the d4rt tool bootstraps at boot so tomReflector's registry
# is non-empty and reflectType()/analysePersistentType() work from a d4rt script.
# The reflection root is lib/src/demo_persistence/reflection_root.dart, configured
# in build.yaml.
#
# Runs flag-free: the generator scans the current project only (framework default
# scan '.', non-recursive), so no --nested and no workspace registry are needed.
#
# Run from the project root:
#   ./reflection_generation.sh
set -e
cd "$(dirname "$0")"
/srv/flutter/flutter/bin/dart run tom_reflection_generator
