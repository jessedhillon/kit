#!/usr/bin/env bash
# Verify CLAUDE.md is consistent with its template and vault sources.
# Fails if CLAUDE.md needs regeneration.
set -euo pipefail

exec python scripts/generate-claude-md.py --check
