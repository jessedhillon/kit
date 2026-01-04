#!/usr/bin/env bash
# Runs the complete test suite: both fresh generation and update path
# This is the main entry point for full validation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║           Kit Template Test Suite                       ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

FAILED=()

run_test() {
    local name="$1"
    local script="$2"
    echo ""
    echo "┌──────────────────────────────────────────────────────────┐"
    echo "│ $name"
    echo "└──────────────────────────────────────────────────────────┘"
    if "$SCRIPT_DIR/$script"; then
        echo ""
        echo "✓ $name PASSED"
    else
        echo ""
        echo "✗ $name FAILED"
        FAILED+=("$name")
    fi
}

# Run tests
run_test "Fresh Generation Test" "test-fresh.sh"
run_test "Update Path Test" "test-update.sh --reset"

# Summary
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                    Test Summary                           ║"
echo "╚══════════════════════════════════════════════════════════╝"

if [[ ${#FAILED[@]} -eq 0 ]]; then
    echo ""
    echo "  ✓ All tests passed!"
    echo ""
    exit 0
else
    echo ""
    echo "  ✗ ${#FAILED[@]} test(s) failed:"
    for test in "${FAILED[@]}"; do
        echo "    - $test"
    done
    echo ""
    exit 1
fi
