#!/usr/bin/env bash
# Fresh minimal/bare/optional projects, isolated runtime tests, and update merge.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
task_tmp="$(mktemp -d)"
trap 'rm -rf "$task_tmp"' EXIT
python3 - "$repo_root" "$task_tmp/source" <<'PY'
import shutil,sys
from pathlib import Path
source,target=map(Path,sys.argv[1:])
shutil.copytree(source/'templates',target/'templates',symlinks=True)
shutil.copy2(source/'copier.yml',target/'copier.yml')
PY
for variant in minimal bare optional; do
  flags=()
  if [[ "$variant" == bare ]]; then
    flags+=(-d include_example_app=false -d include_example_model=false)
  elif [[ "$variant" == optional ]]; then
    flags+=(-d include_llm_scaffold=true -d include_session_journal=true -d include_tunnels=true)
  fi
  copier copy --trust --defaults --data-file "$repo_root/tests/answers.yml" "${flags[@]}" "$task_tmp/source" "$task_tmp/$variant"
  uv venv "$task_tmp/$variant-venv" --python python3.13
  uv pip install --python "$task_tmp/$variant-venv/bin/python" -e "$task_tmp/$variant[test]"
  "$task_tmp/$variant-venv/bin/python" -m compileall -q "$task_tmp/$variant/testproject"
  KIT_RENDERED_ROOT="$task_tmp/$variant" KIT_TEST_OPTIONAL="$([[ "$variant" == optional ]] && echo 1 || echo 0)" \
    "$task_tmp/$variant-venv/bin/python" -m pytest -q "$repo_root/tests/runtime"
done
python3 "$repo_root/tests/scripts/test-backport-update.py"
