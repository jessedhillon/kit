#!/usr/bin/env bash
# Run nix fmt and automatically restage any files it modified.
# This prevents the "files were modified by this hook" failure loop.
set -euo pipefail

declare -A before
for f in "$@"; do
  if [[ -f "$f" ]]; then
    before["$f"]="$(md5sum "$f" | cut -d' ' -f1)"
  fi
done

nix fmt "$@"

changed=0
for f in "$@"; do
  if [[ -f "$f" ]]; then
    after="$(md5sum "$f" | cut -d' ' -f1)"
    if [[ "${before[$f]:-}" != "$after" ]]; then
      git add "$f"
      changed=$((changed + 1))
    fi
  fi
done

if [[ $changed -gt 0 ]]; then
  echo "Auto-restaged $changed file(s) after formatting."
fi
