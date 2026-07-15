#!/bin/bash
# tom_core_d4rt example runner
#
# Runs every example .d4rt script in this folder in test mode (asserting mode)
# and reports pass/fail. Each script also prints its real runtime output; run a
# single script directly to read it, e.g.:
#
#   dart run bin/d4rt.dart -run-replay example/01_crypto_example.d4rt
#
# The runner uses the JIT entry point (dart run bin/d4rt.dart) so it works
# without a precompiled binary. Requires DART_SDK to be set (or auto-detected).

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "========================================"
echo "tom_core_d4rt example runner"
echo "========================================"
echo ""

TOTAL=0
PASSED=0
FAILED=0

cd "$PROJECT_DIR"
for example_file in "$SCRIPT_DIR"/*.d4rt; do
    [ -f "$example_file" ] || continue
    TOTAL=$((TOTAL + 1))
    example_name=$(basename "$example_file")
    echo -en "${CYAN}Running $example_name...${NC} "
    if dart run bin/d4rt.dart -run-replay "$example_file" -test >/dev/null 2>&1; then
        echo -e "${GREEN}PASSED${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}FAILED${NC}"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "========================================"
echo "Example Results: $PASSED/$TOTAL passed"
if [ $FAILED -gt 0 ]; then
    echo -e "${RED}$FAILED example(s) failed${NC}"
    exit 1
else
    echo -e "${GREEN}All examples passed!${NC}"
    exit 0
fi
