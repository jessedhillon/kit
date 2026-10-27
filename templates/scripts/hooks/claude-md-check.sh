#!/usr/bin/env bash
set -euo pipefail
repo_root="$(git rev-parse --show-toplevel)"
if [[ ! -x "$repo_root/.venv/bin/python" ]]; then
  echo "Skipping generated-document check: no project virtualenv" >&2
  exit 0
fi
cd "$repo_root"
exec "$repo_root/.venv/bin/python" scripts/generate-claude-md.py --check
