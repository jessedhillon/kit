#!/usr/bin/env bash
# Tests the update path for existing projects
# Updates the committed fixture and validates it

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
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
echo "Template: $REPO_ROOT"
echo "Fixture:  $FIXTURE_DIR"
echo ""

# Update the fixture
echo "--- Updating fixture ---"
cd "$FIXTURE_DIR"

copier update \
    --trust \
    --defaults \
    .

echo ""
echo "✓ Fixture updated successfully"

# Show what changed (from parent repo's perspective)
if [[ "$SHOW_DIFF" == "true" ]]; then
    echo ""
    echo "--- Changes from update ---"
    cd "$REPO_ROOT"
    if git diff --quiet -- tests/fixture; then
        echo "(no changes)"
    else
        git diff --stat -- tests/fixture
        echo ""
        echo "Run 'git diff tests/fixture' for full details"
    fi
    cd "$FIXTURE_DIR"
fi

# Validate the updated fixture
"$SCRIPT_DIR/validate-project.sh" "$FIXTURE_DIR"

# Reset if requested (restore from parent repo)
if [[ "$RESET_AFTER" == "true" ]]; then
    echo ""
    echo "--- Resetting fixture ---"
    cd "$REPO_ROOT"
    git checkout -- tests/fixture
    git clean -fd tests/fixture
    echo "✓ Fixture reset to pre-update state"
fi
