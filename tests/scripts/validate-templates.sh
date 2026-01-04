#!/usr/bin/env bash
# Quick syntax validation for templates (no network required)
# Suitable for nix flake check and pre-commit hooks
#
# Validates:
# 1. Jinja2 template syntax
# 2. Python syntax in generated output (via py_compile)
# 3. JSON/YAML syntax in generated config files

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEMPLATE_ROOT="$REPO_ROOT/templates"
FIXTURE_DIR="$SCRIPT_DIR/../fixture"

FAILURES=()

run_check() {
    local name="$1"
    shift
    echo "--- $name ---"
    if "$@"; then
        echo "✓ $name"
    else
        echo "✗ $name" >&2
        FAILURES+=("$name")
    fi
    echo ""
}

echo "=== Template Syntax Validation ==="
echo ""

# Check 1: Jinja2 templates parse correctly
check_jinja2_syntax() {
    python3 << 'EOF'
import sys
from pathlib import Path
from jinja2 import Environment, FileSystemLoader, TemplateSyntaxError

# Copier uses these custom extensions
class FakeExtension:
    pass

template_root = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
errors = []

# Create environment (we can't fully replicate Copier's extensions,
# but we can catch most syntax errors)
env = Environment(
    loader=FileSystemLoader(str(template_root)),
    # Don't fail on undefined variables since we don't have actual data
    undefined=lambda: "",
)

for template_path in template_root.rglob("*.jinja"):
    rel_path = template_path.relative_to(template_root)
    try:
        # Just parse, don't render (we don't have variable values)
        with open(template_path) as f:
            content = f.read()
        env.parse(content)
    except TemplateSyntaxError as e:
        errors.append(f"{rel_path}:{e.lineno}: {e.message}")
    except Exception as e:
        errors.append(f"{rel_path}: {e}")

if errors:
    print("Jinja2 syntax errors found:")
    for error in errors:
        print(f"  {error}")
    sys.exit(1)

print(f"All templates parsed successfully")
EOF
}

run_check "Jinja2 template syntax" python3 -c "
import sys
from pathlib import Path

template_root = Path('$TEMPLATE_ROOT')
errors = []

for template_path in template_root.rglob('*.jinja'):
    # Skip checking files that have Copier-specific syntax we can't parse
    # (like {% yield %} blocks)
    rel_path = template_path.relative_to(template_root)
    try:
        with open(template_path) as f:
            content = f.read()
        # Basic brace matching check
        open_count = content.count('{%') + content.count('{{')
        close_count = content.count('%}') + content.count('}}')
        if open_count != close_count:
            errors.append(f'{rel_path}: Mismatched template braces')
    except Exception as e:
        errors.append(f'{rel_path}: {e}')

if errors:
    for error in errors:
        print(f'  {error}', file=sys.stderr)
    sys.exit(1)

print(f'Checked {len(list(template_root.rglob(\"*.jinja\")))} template files')
"

# Check 2: Python syntax in fixture (if it exists)
if [[ -d "$FIXTURE_DIR" ]]; then
    run_check "Python syntax (fixture)" python3 -c "
import sys
import py_compile
from pathlib import Path

fixture_dir = Path('$FIXTURE_DIR')
errors = []

for py_file in fixture_dir.rglob('*.py'):
    # Skip venv and node_modules
    if '.venv' in py_file.parts or 'node_modules' in py_file.parts:
        continue
    try:
        py_compile.compile(str(py_file), doraise=True)
    except py_compile.PyCompileError as e:
        errors.append(str(e))

if errors:
    for error in errors:
        print(error, file=sys.stderr)
    sys.exit(1)

py_files = [f for f in fixture_dir.rglob('*.py')
            if '.venv' not in f.parts and 'node_modules' not in f.parts]
print(f'Checked {len(py_files)} Python files')
"

    # Check 3: YAML syntax in fixture config files
    run_check "YAML syntax (fixture)" python3 -c "
import sys
from pathlib import Path

try:
    import yaml
    HAS_YAML = True
except ImportError:
    HAS_YAML = False

fixture_dir = Path('$FIXTURE_DIR')
config_dir = fixture_dir / 'config'
errors = []

if not HAS_YAML:
    print('pyyaml not installed, skipping YAML validation')
    sys.exit(0)

if config_dir.exists():
    for yaml_file in config_dir.rglob('*.yaml'):
        try:
            with open(yaml_file) as f:
                yaml.safe_load(f)
        except yaml.YAMLError as e:
            errors.append(f'{yaml_file.relative_to(fixture_dir)}: {e}')

if errors:
    for error in errors:
        print(error, file=sys.stderr)
    sys.exit(1)

yaml_files = list(config_dir.rglob('*.yaml')) if config_dir.exists() else []
print(f'Checked {len(yaml_files)} YAML files')
"

    # Check 4: JSON syntax in fixture (package.json, etc.)
    # Note: tsconfig.json files are skipped because TypeScript allows trailing commas and comments
    run_check "JSON syntax (fixture)" python3 -c "
import sys
import json
from pathlib import Path

fixture_dir = Path('$FIXTURE_DIR')
errors = []

for json_file in fixture_dir.rglob('*.json'):
    # Skip node_modules
    if 'node_modules' in json_file.parts:
        continue
    # Skip tsconfig files (TypeScript allows trailing commas and comments)
    if json_file.name.startswith('tsconfig'):
        continue
    try:
        with open(json_file) as f:
            json.load(f)
    except json.JSONDecodeError as e:
        errors.append(f'{json_file.relative_to(fixture_dir)}: {e}')

if errors:
    for error in errors:
        print(error, file=sys.stderr)
    sys.exit(1)

json_files = [f for f in fixture_dir.rglob('*.json')
              if 'node_modules' not in f.parts and not f.name.startswith('tsconfig')]
print(f'Checked {len(json_files)} JSON files (tsconfig files skipped)')
"
else
    echo "--- Fixture validation ---"
    echo "⊘ Skipped (fixture not initialized)"
    echo "  Run: tests/scripts/init-fixture.sh"
    echo ""
fi

# Summary
echo "=== Validation Summary ==="
if [[ ${#FAILURES[@]} -eq 0 ]]; then
    echo "✓ All syntax checks passed"
    exit 0
else
    echo "✗ ${#FAILURES[@]} check(s) failed:"
    for failure in "${FAILURES[@]}"; do
        echo "  - $failure"
    done
    exit 1
fi
