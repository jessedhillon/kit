#!/usr/bin/env bash
# Initializes the committed fixture project
# Run this once to create the initial fixture, then commit it

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEMPLATE_ROOT="$REPO_ROOT/templates"
ANSWERS_FILE="$SCRIPT_DIR/../answers.yml"
FIXTURE_DIR="$SCRIPT_DIR/../fixture"

if [[ -d "$FIXTURE_DIR" ]]; then
    echo "Error: Fixture directory already exists: $FIXTURE_DIR" >&2
    echo ""
    echo "To reinitialize, first remove it:"
    echo "  rm -rf $FIXTURE_DIR"
    exit 1
fi

echo "=== Initializing Fixture ==="
echo "Template: $TEMPLATE_ROOT"
echo "Output:   $FIXTURE_DIR"
echo "Answers:  $ANSWERS_FILE"
echo ""

# Generate the fixture
echo "--- Generating fixture ---"
copier copy \
    --trust \
    --defaults \
    --data-file "$ANSWERS_FILE" \
    "$TEMPLATE_ROOT" \
    "$FIXTURE_DIR"

echo ""
echo "✓ Fixture generated successfully"

echo ""
echo "=== Fixture Ready ==="
echo ""
echo "Next steps:"
echo "1. Review the generated fixture in: $FIXTURE_DIR"
echo "2. Commit the fixture to the template repository:"
echo "   git add tests/fixture"
echo "   git commit -m 'Add test fixture'"
echo ""
echo "To validate the fixture:"
echo "   tests/scripts/validate-project.sh tests/fixture"
