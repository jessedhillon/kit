#!/usr/bin/env bash
# Tests fresh project generation from the template
# Generates a new project in a temporary directory and validates it

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ANSWERS_FILE="$SCRIPT_DIR/../answers.yml"

# Parse arguments
KEEP_TEMP=false
TEMP_DIR=""

usage() {
    echo "Usage: test-fresh.sh [--keep] [--dir <directory>]"
    echo ""
    echo "Options:"
    echo "  --keep    Keep the temporary directory after test (for debugging)"
    echo "  --dir     Use specified directory instead of creating temp dir"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --keep)
            KEEP_TEMP=true
            shift
            ;;
        --dir)
            TEMP_DIR="$2"
            KEEP_TEMP=true
            shift 2
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

# Create or use temp directory
if [[ -z "$TEMP_DIR" ]]; then
    TEMP_DIR="$(mktemp -d)"
fi

cleanup() {
    if [[ "$KEEP_TEMP" == "false" && -d "$TEMP_DIR" ]]; then
        echo "Cleaning up: $TEMP_DIR"
        rm -rf "$TEMP_DIR"
    fi
}

if [[ "$KEEP_TEMP" == "false" ]]; then
    trap cleanup EXIT
fi

echo "=== Fresh Generation Test ==="
echo "Template: $REPO_ROOT"
echo "Output:   $TEMP_DIR"
echo "Answers:  $ANSWERS_FILE"
echo ""

# Generate project
echo "--- Generating project ---"
copier copy \
    --trust \
    --defaults \
    --data-file "$ANSWERS_FILE" \
    "$REPO_ROOT" \
    "$TEMP_DIR"

echo ""
echo "✓ Project generated successfully"

# If a sibling nix-templates repo exists, simulate the post-copier flake init.
# Falls back silently for CI environments without local nix-templates access.
NIX_TEMPLATES_DIR="$(cd "$REPO_ROOT/../nix-templates" 2>/dev/null && pwd || true)"
if [[ -n "$NIX_TEMPLATES_DIR" && -d "$NIX_TEMPLATES_DIR/dev-kit" ]]; then
    echo ""
    echo "--- Initializing flake from $NIX_TEMPLATES_DIR#dev-kit ---"
    (cd "$TEMP_DIR" && nix flake init -t "path:$NIX_TEMPLATES_DIR#dev-kit")
    echo "✓ Flake initialized"
else
    echo ""
    echo "⊘ Skipping flake init (sibling ../nix-templates not found)"
fi

# Validate the generated project
"$SCRIPT_DIR/validate-project.sh" "$TEMP_DIR"

if [[ "$KEEP_TEMP" == "true" ]]; then
    echo ""
    echo "Generated project kept at: $TEMP_DIR"
fi
