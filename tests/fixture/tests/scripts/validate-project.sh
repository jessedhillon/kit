#!/usr/bin/env bash
# Validates a generated project by running the full test suite
# Usage: validate-project.sh <project-dir>

set -euo pipefail

PROJECT_DIR="${1:?Usage: validate-project.sh <project-dir>}"

if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "Error: Project directory does not exist: $PROJECT_DIR" >&2
    exit 1
fi

cd "$PROJECT_DIR"

echo "=== Validating project in: $PROJECT_DIR ==="

# Track failures
FAILURES=()

run_step() {
    local name="$1"
    shift
    echo ""
    echo "--- $name ---"
    if "$@"; then
        echo "✓ $name passed"
    else
        echo "✗ $name failed" >&2
        FAILURES+=("$name")
    fi
}

# Python validation
echo ""
echo "=== Python Validation ==="

run_step "poetry install" poetry install --no-interaction

run_step "pyright" poetry run pyright

run_step "ruff check" poetry run ruff check .

run_step "ruff format --check" poetry run ruff format --check .

# Only run pytest if tests directory exists and has test files
if compgen -G "tests/test_*.py" > /dev/null 2>&1; then
    run_step "pytest" poetry run pytest
else
    echo ""
    echo "--- pytest ---"
    echo "⊘ pytest skipped (no test files found)"
fi

# Frontend validation (for each web app)
for frontend_dir in */web/*/frontend; do
    if [[ -d "$frontend_dir" ]]; then
        echo ""
        echo "=== Frontend Validation: $frontend_dir ==="

        pushd "$frontend_dir" > /dev/null

        run_step "npm install ($frontend_dir)" npm install

        run_step "npm run build ($frontend_dir)" npm run build

        run_step "eslint ($frontend_dir)" npm run lint --if-present

        popd > /dev/null
    fi
done

# Summary
echo ""
echo "=== Validation Summary ==="
if [[ ${#FAILURES[@]} -eq 0 ]]; then
    echo "✓ All validations passed"
    exit 0
else
    echo "✗ ${#FAILURES[@]} validation(s) failed:"
    for failure in "${FAILURES[@]}"; do
        echo "  - $failure"
    done
    exit 1
fi
