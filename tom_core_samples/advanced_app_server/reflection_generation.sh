#!/usr/bin/env bash
# Regenerate bin/app_server_start.reflection.dart.
# Uses build.yaml config (targets bin/app_server_start.dart).
#
# `--nested` runs the generator in single-project mode (it does not rely on the
# workspace registry, so it works before this sample is registered in
# tom_master.yaml).
#
# Run from the project root:
#   ./reflection_generation.sh
set -e
cd "$(dirname "$0")"
/srv/flutter/flutter/bin/dart run tom_reflection_generator --nested
