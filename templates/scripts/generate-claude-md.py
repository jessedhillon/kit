"""Render agent markdown files from co-located Jinja2 templates.

Usage:
    python scripts/generate-claude-md.py [--check]

Discovers all CLAUDE.md.j2 and AGENTS.md.j2 files in the repo. For each,
renders the template and writes (or checks) the neighboring .md file.

Without --check: writes rendered output.
With --check: compares rendered output to existing files, exits non-zero if any differ.
"""

import re
import subprocess
import sys
import typing as t
from pathlib import Path

import yaml

project_root = Path(__file__).resolve().parent.parent
vault_root = project_root / "docs.vault"
answers_path = project_root / ".copier-answers.yml"

template_names = {"CLAUDE.md.j2", "AGENTS.md.j2"}


def read_answers() -> dict[str, t.Any]:
    """Read project metadata from .copier-answers.yml."""
    if not answers_path.exists():
        return {}
    return yaml.safe_load(answers_path.read_text()) or {}


def read_vault(relative_path: str) -> str:
    """Read a vault document, stripping any YAML frontmatter."""
    path = vault_root / relative_path
    content = path.read_text()
    if content.startswith("---"):
        end = content.find("---", 3)
        if end != -1:
            content = content[end + 3 :].lstrip("\n")
    return content


def extract_section(content: str, heading: str, *, level: int = 2) -> str:
    """Extract a section from markdown content by heading.

    Returns everything from the heading (exclusive) to the next heading of
    the same or higher level, stripped of leading/trailing whitespace.
    Ignores headings inside fenced code blocks.
    """
    prefix = "#" * level
    pattern = rf"^{prefix}\s+{re.escape(heading)}\s*$"
    lines = content.split("\n")
    start = None
    in_fence = False
    for i, line in enumerate(lines):
        if line.startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        if start is None:
            if re.match(pattern, line):
                start = i + 1
        else:
            if re.match(rf"^#{{{1},{level}}}\s+", line):
                return "\n".join(lines[start:i]).strip()
    if start is not None:
        return "\n".join(lines[start:]).strip()
    msg = f"section '{heading}' (h{level}) not found"
    raise ValueError(msg)


def strip_title(content: str) -> str:
    """Strip the first h1 heading from content."""
    lines = content.split("\n")
    for i, line in enumerate(lines):
        if line.startswith("# "):
            return "\n".join(lines[i + 1 :]).lstrip("\n")
    return content


def vault_section(relative_path: str, heading: str, *, level: int = 2) -> str:
    """Read a vault doc and extract a specific section."""
    content = read_vault(relative_path)
    return extract_section(content, heading, level=level)


def indent(text: str, prefix: str) -> str:
    """Indent all lines of text with prefix."""
    return "\n".join(prefix + line if line.strip() else line for line in text.split("\n"))


def bump_headings(text: str, levels: int = 1) -> str:
    """Increase markdown heading depth by N levels (e.g. ## becomes ### with levels=1)."""
    prefix = "#" * levels

    def bump_line(line: str) -> str:
        if line.startswith("#"):
            return prefix + line
        return line

    return "\n".join(bump_line(line) for line in text.split("\n"))


def discover_templates() -> list[Path]:
    """Find all CLAUDE.md.j2 and AGENTS.md.j2 files in the repo."""
    templates: list[Path] = []
    for path in project_root.rglob("*.md.j2"):
        if path.name in template_names and ".state" not in path.parts:
            templates.append(path)
    return sorted(templates)


def render(template_path: Path, answers: dict[str, t.Any]) -> str:
    """Render a single template file."""
    import jinja2

    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader(str(template_path.parent)),
        keep_trailing_newline=True,
        undefined=jinja2.StrictUndefined,
    )
    globals_dict = t.cast(dict[str, t.Any], env.globals)
    globals_dict["read_vault"] = read_vault
    globals_dict["vault_section"] = vault_section
    globals_dict["strip_title"] = strip_title
    globals_dict["extract_section"] = extract_section
    globals_dict["bump_headings"] = bump_headings

    # Project metadata — pulled from copier answers so CLAUDE.md/AGENTS.md
    # templates can reference module_name, project_name, etc. without
    # needing copier-time substitution.
    module_name = answers.get("module_name", "")
    globals_dict["module_name"] = module_name
    globals_dict["project_name"] = answers.get("project_name", "")
    globals_dict["project_description"] = answers.get("project_description", "")
    globals_dict["class_prefix"] = answers.get("class_prefix", "")
    globals_dict["linear_prefix"] = module_name[:3].upper() if module_name else ""

    template = env.get_template(template_path.name)
    return template.render()


def fmt(paths: list[Path]):
    if paths:
        subprocess.run(["nix", "fmt", "--", *[str(p) for p in paths]], check=False)


def main():
    check_mode = "--check" in sys.argv

    templates = discover_templates()
    if not templates:
        sys.stderr.write("No CLAUDE.md.j2 or AGENTS.md.j2 templates found.\n")
        sys.exit(1)

    answers = read_answers()

    output_paths: list[Path] = []
    failures: list[str] = []
    for template_path in templates:
        output_path = template_path.with_suffix("")
        rendered = render(template_path, answers)
        relative = output_path.relative_to(project_root)

        if check_mode:
            if not output_path.exists():
                failures.append(f"{relative} does not exist. Run `generate-claude-md` to create it.")
                continue
            tmp_path = output_path.parent / f".{output_path.stem}-check.md"
            tmp_path.write_text(rendered)
            try:
                fmt([tmp_path])
                formatted = tmp_path.read_text()
            finally:
                tmp_path.unlink()
            existing = output_path.read_text()
            if formatted != existing:
                failures.append(f"{relative} is out of date. Run `generate-claude-md` to regenerate.")
        else:
            output_path.write_text(rendered)
            output_paths.append(output_path)
            sys.stdout.write(f"{relative} regenerated.\n")

    if not check_mode:
        fmt(output_paths)

    if failures:
        for msg in failures:
            sys.stderr.write(f"{msg}\n")
        sys.exit(1)


if __name__ == "__main__":
    main()
