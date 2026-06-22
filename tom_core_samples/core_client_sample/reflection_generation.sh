#!/usr/bin/env bash
# Regenerate lib/reflection_seed.reflection.dart from lib/reflection_seed.dart.
# Single-project mode (--nested) reads build.yaml's generate_for, which targets
# lib/reflection_seed.dart. Run from the project root:
#   ./reflection_generation.sh
set -e
cd "$(dirname "$0")"
/srv/flutter/flutter/bin/dart run tom_reflection_generator --nested
