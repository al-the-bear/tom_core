#!/usr/bin/env bash
# Regenerate bin/server_start.reflection.dart (the reflection metadata the live
# server boot needs: config class, endpoint service, persistence records, and
# the transitively-reached MariaDB driver/migrator/grant types). The reflection
# root is bin/server_start.dart, configured in build.yaml.
#
# `--nested` runs the generator in single-project mode (no workspace registry),
# so it works before this sample is registered in tom_master.yaml.
#
# Run from the project root:
#   ./reflection_generation.sh
set -e
cd "$(dirname "$0")"
/srv/flutter/flutter/bin/dart run tom_reflection_generator --nested
