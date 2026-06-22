#!/usr/bin/env bash
# Regenerate lib/src/reflection_entry.reflection.dart (the persistence records'
# reflection metadata the live server boot needs). Uses build.yaml config.
#
# `--nested` runs the generator in single-project mode (no workspace registry),
# so it works before this sample is registered in tom_master.yaml.
#
# Run from the project root:
#   ./reflection_generation.sh
set -e
cd "$(dirname "$0")"
/srv/flutter/flutter/bin/dart run tom_reflection_generator --nested
