#!/usr/bin/env bash
# Run pyright only if a venv is available. Skip gracefully in worktrees
# where poetry install hasn't been run yet.
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"

if [[ ! -d "${repo_root}/.venv" ]]; then
  echo "Skipping pyright: no .venv found at ${repo_root}" >&2
  echo "Run 'poetry install' to enable pyright checks." >&2
  exit 0
fi

exec pyright "$@"
