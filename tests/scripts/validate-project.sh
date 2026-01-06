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

# Set up local environment to avoid polluting user's home directory
export XDG_STATE_HOME="$PWD/.state"
export XDG_CACHE_HOME="$PWD/.cache"
export POETRY_VIRTUALENVS_IN_PROJECT=true
export NPM_CONFIG_CACHE="$PWD/.cache/npm"

mkdir -p "$XDG_STATE_HOME" "$XDG_CACHE_HOME" "$NPM_CONFIG_CACHE"

# Create and activate virtualenv if it doesn't exist
if [[ ! -d ".venv" ]]; then
    echo "=== Creating virtualenv ==="
    python -m venv .venv
fi
source .venv/bin/activate

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

run_step "poetry install" poetry install --no-interaction --extras dev --extras test

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
# First, install npm dependencies for all frontends
for frontend_dir in */web/*/frontend; do
    if [[ -d "$frontend_dir" ]]; then
        echo ""
        echo "=== Frontend Setup: $frontend_dir ==="
        pushd "$frontend_dir" > /dev/null
        run_step "npm install ($frontend_dir)" npm install
        popd > /dev/null
    fi
done

# Generate API clients (requires running API server)
# Find the module name from the directory structure
MODULE_NAME=$(ls -d */ 2>/dev/null | grep -v tests | grep -v migrations | grep -v config | head -1 | tr -d '/')
if [[ -n "$MODULE_NAME" ]] && compgen -G "$MODULE_NAME/web/*/frontend" > /dev/null 2>&1; then
    echo ""
    echo "=== API Client Generation ==="

    SERVER_PIDS=()

    # Start a server for each web app
    for app_dir in "$MODULE_NAME"/web/*/; do
        if [[ -d "$app_dir" ]]; then
            app_name=$(basename "$app_dir")
            echo "Starting API server for $app_name..."
            poetry run python -m "$MODULE_NAME.cli" web serve "$app_name" &
            SERVER_PIDS+=($!)
        fi
    done

    # Wait for servers to be ready (check openapi.json endpoint)
    echo "Waiting for API servers to be ready..."
    for i in {1..30}; do
        if curl -sf http://localhost:8081/openapi.json > /dev/null 2>&1; then
            echo "API server ready"
            break
        fi
        sleep 1
    done

    # Generate clients for each frontend
    for frontend_dir in "$MODULE_NAME"/web/*/frontend; do
        if [[ -d "$frontend_dir" ]]; then
            pushd "$frontend_dir" > /dev/null
            run_step "generate-api-client ($frontend_dir)" npx openapi-ts
            popd > /dev/null
        fi
    done

    # Stop all servers
    echo "Stopping API servers..."
    for pid in "${SERVER_PIDS[@]}"; do
        kill "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
    done
fi

# Build and lint frontends
for frontend_dir in */web/*/frontend; do
    if [[ -d "$frontend_dir" ]]; then
        echo ""
        echo "=== Frontend Build: $frontend_dir ==="

        pushd "$frontend_dir" > /dev/null

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
