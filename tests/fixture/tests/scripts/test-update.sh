#!/usr/bin/env bash
# Tests the update path for existing projects
# Updates the committed fixture and validates it

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FIXTURE_DIR="$SCRIPT_DIR/../fixture"

# Parse arguments
SHOW_DIFF=true
RESET_AFTER=false

usage() {
    echo "Usage: test-update.sh [--no-diff] [--reset]"
    echo ""
    echo "Options:"
    echo "  --no-diff   Don't show git diff after update"
    echo "  --reset     Reset fixture to pre-update state after test"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-diff)
            SHOW_DIFF=false
            shift
            ;;
        --reset)
            RESET_AFTER=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            ;;
    esac
done

if [[ ! -d "$FIXTURE_DIR" ]]; then
    echo "Error: Fixture directory does not exist: $FIXTURE_DIR" >&2
    echo ""
    echo "To initialize the fixture, run:"
    echo "  tests/scripts/init-fixture.sh"
    exit 1
fi

echo "=== Update Path Test ==="
echo "Template: $TEMPLATE_ROOT"
echo "Fixture:  $FIXTURE_DIR"
echo ""

# Store current state for potential reset
ORIGINAL_HEAD=""
if [[ "$RESET_AFTER" == "true" ]]; then
    pushd "$FIXTURE_DIR" > /dev/null
    if git rev-parse --git-dir > /dev/null 2>&1; then
        ORIGINAL_HEAD="$(git rev-parse HEAD 2>/dev/null || echo "")"
    fi
    popd > /dev/null
fi

# Update the fixture
echo "--- Updating fixture ---"
cd "$FIXTURE_DIR"

copier update \
    --trust \
    --defaults \
    .

echo ""
echo "✓ Fixture updated successfully"

# Show what changed
if [[ "$SHOW_DIFF" == "true" ]]; then
    echo ""
    echo "--- Changes from update ---"
    if git rev-parse --git-dir > /dev/null 2>&1; then
        if git diff --quiet; then
            echo "(no changes)"
        else
            git diff --stat
            echo ""
            echo "Run 'git diff' in $FIXTURE_DIR for full details"
        fi
    else
        echo "(fixture is not a git repository, cannot show diff)"
    fi
fi

# Validate the updated fixture
"$SCRIPT_DIR/validate-project.sh" "$FIXTURE_DIR"

# Reset if requested
if [[ "$RESET_AFTER" == "true" && -n "$ORIGINAL_HEAD" ]]; then
    echo ""
    echo "--- Resetting fixture ---"
    cd "$FIXTURE_DIR"
    git checkout .
    git clean -fd
    echo "✓ Fixture reset to pre-update state"
fi
