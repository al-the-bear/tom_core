#!/usr/bin/env bash
# Regenerate lib/reflection_seed.reflection.dart from lib/reflection_seed.dart.
# Single-project mode (--nested) reads build.yaml's generate_for, which targets
# lib/reflection_seed.dart. (A positional `build` arg is treated as a target
# filter and matches nothing here — use --nested.)
#
# Run from the project root:
#   ./reflection_generation.sh
set -e
cd "$(dirname "$0")"
/srv/flutter/flutter/bin/dart run tom_reflection_generator --nested
