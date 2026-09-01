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
# Resolve the Dart SDK: an explicit $DART wins, otherwise `dart` from PATH.
# Why no baked-in SDK path: the fleet's hosts install Dart in different places,
# so any absolute default is wrong on most of them and fails with a bare "no
# such file or directory" quoting a path the reader has never seen. Failing
# loudly, with the remedy in the message, is cheaper than guessing.
DART="${DART:-$(command -v dart || true)}"
if [ -z "$DART" ]; then
  echo "reflection_generation.sh: no 'dart' found on PATH." >&2
  echo "  Install the Dart or Flutter SDK and put its bin/ on PATH, or rerun as:" >&2
  echo "    DART=/path/to/dart $0" >&2
  exit 1
fi
"$DART" run tom_reflection_generator --nested
