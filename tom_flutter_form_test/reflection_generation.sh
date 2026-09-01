#!/usr/bin/env bash
# Regenerate main.reflection.dart from lib/main.dart.
# Uses build.yaml config (targets lib/main.dart).
#
# Run from the project root:
#   ./reflection_generation.sh
#
# Why `--nested` and no other argument: the generator's CLI takes *paths*, not
# subcommands. `--nested` is single-project mode, in which it reads build.yaml
# and generates for the `generate_for` entry. Passing a bare word such as
# `build` makes the CLI treat it as a path — and because this project has a
# `build/` directory, it resolved to that, warned "build is a directory" and
# generated nothing while still exiting 0.
set -e
cd "$(dirname "$0")"
dart run tom_reflection_generator --nested
