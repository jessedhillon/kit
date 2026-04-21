#!/usr/bin/env python
"""Render WORKTREE.md.j2 from environment variables and project metadata.

Env vars:
    PRJ_ROOT         — project root (required, set by devshell)
    AGENT_PROJECT    — Linear project name (optional)
    AGENT_ISSUE_IDS  — comma-separated issue IDs (optional)

Template context (populated automatically):
    project          — from AGENT_PROJECT (if set)
    issue_ids        — from AGENT_ISSUE_IDS, normalized with linear_prefix
    module_name      — from .copier-answers.yml
    linear_prefix    — first 3 letters of module_name, uppercased
"""

import os
import pathlib
import sys

import yaml
from jinja2 import Environment

prj_root = pathlib.Path(os.environ["PRJ_ROOT"])

answers_path = prj_root / ".copier-answers.yml"
answers = yaml.safe_load(answers_path.read_text()) if answers_path.exists() else {}
module_name = answers.get("module_name", prj_root.name)
linear_prefix = module_name[:3].upper()

tpl = (prj_root / "WORKTREE.md.j2").read_text()

ctx: dict[str, object] = {
    "module_name": module_name,
    "linear_prefix": linear_prefix,
}

project = os.environ.get("AGENT_PROJECT", "")
issue_ids = os.environ.get("AGENT_ISSUE_IDS", "")

if project:
    ctx["project"] = project

if issue_ids:
    ids = [i.strip() for i in issue_ids.split(",")]
    prefix = f"{linear_prefix}-"
    ctx["issue_ids"] = [i if i.startswith(prefix) else prefix + i for i in ids]

sys.stdout.write(Environment().from_string(tpl).render(**ctx))
