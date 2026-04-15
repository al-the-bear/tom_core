#!/usr/bin/env bash
# Regenerate main.reflection.dart from lib/main.dart.
# Uses build.yaml config (targets lib/main.dart).
#
# Run from the project root:
#   ./reflection_generation.sh
set -e
cd "$(dirname "$0")"
/srv/flutter/flutter/bin/dart run tom_reflection_generator build
