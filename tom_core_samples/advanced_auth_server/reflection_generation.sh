#!/usr/bin/env bash
# Regenerate bin/auth_server_start.reflection.dart.
# Uses build.yaml config (targets bin/auth_server_start.dart).
#
# Runs flag-free: the generator scans the current project only (the framework
# default is scan '.', non-recursive), so no --nested and no workspace registry
# are needed.
#
# Run from the project root:
#   ./reflection_generation.sh
#
# Verify instead of regenerate — fails, naming the file, if the committed
# output no longer matches its source (drift that a clean analyze and a
# green suite do not reveal):
#   ./reflection_generation.sh --check
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
"$DART" run tom_reflection_generator "$@"
