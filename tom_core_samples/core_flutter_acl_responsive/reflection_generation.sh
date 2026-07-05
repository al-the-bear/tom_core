#!/usr/bin/env bash
# Regenerate lib/reflection_seed.reflection.dart from lib/reflection_seed.dart.
# Runs flag-free: the generator scans the current project only (framework
# default scan '.', non-recursive) and reads build.yaml's generate_for, which
# targets lib/reflection_seed.dart. (Do not pass a positional `build` arg — it is
# treated as a target filter and would match nothing here.)
#
# Run from the project root:
#   ./reflection_generation.sh
set -e
cd "$(dirname "$0")"
/srv/flutter/flutter/bin/dart run tom_reflection_generator
