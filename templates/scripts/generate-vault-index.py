"""Render the docs.vault index from filesystem structure and frontmatter.

Usage:
    python scripts/generate-vault-index.py [--check]

Scans docs.vault/ for areas, categories, and nodes. Reads `description`
from each node's YAML frontmatter. Renders 00.00 index.md from the
co-located .j2 template.

Without --check: writes rendered output.
With --check: compares to existing file, exits non-zero if different.
"""

import re
import subprocess
import sys
import typing as t
from dataclasses import dataclass, field
from pathlib import Path

import yaml

project_root = Path(__file__).resolve().parent.parent
vault_root = project_root / "docs.vault"
index_dir = vault_root / "00-09 meta" / "00 index"
index_path = index_dir / "00.00 index.md"
template_path = index_dir / "00.00 index.md.j2"

node_pattern = re.compile(r"^(\d{2}\.\d{2})\s+(.+?)(?:\.md)?$")
category_pattern = re.compile(r"^(\d{2})\s+(.+)$")
area_pattern = re.compile(r"^(\d{2})-(\d{2})\s+(.+)$")


@dataclass
class Node(object):
    id: str
    name: str
    description: str
    is_directory: bool = False


@dataclass
class Category(object):
    id: str
    name: str
    nodes: list[Node] = field(default_factory=lambda: [])


@dataclass
class Area(object):
    range_start: str
    range_end: str
    name: str
    categories: list[Category] = field(default_factory=lambda: [])

    @property
    def range_label(self) -> str:
        return f"{self.range_start}-{self.range_end}"


def read_frontmatter(path: Path) -> dict[str, t.Any]:
    """Read YAML frontmatter from a markdown file."""
    content = path.read_text()
    if not content.startswith("---"):
        return {}
    end = content.find("---", 3)
    if end == -1:
        return {}
    fm = content[3:end].strip()
    return yaml.safe_load(fm) or {}


def scan_vault() -> list[Area]:
    """Scan docs.vault/ directory structure and return areas with categories and nodes."""
    areas: list[Area] = []

    for area_dir in sorted(vault_root.iterdir()):
        if not area_dir.is_dir():
            continue
        m = area_pattern.match(area_dir.name)
        if not m:
            continue
        area = Area(range_start=m.group(1), range_end=m.group(2), name=m.group(3))

        for cat_dir in sorted(area_dir.iterdir()):
            if not cat_dir.is_dir():
                continue
            cm = category_pattern.match(cat_dir.name)
            if not cm:
                continue
            category = Category(id=cm.group(1), name=cm.group(2))

            for entry in sorted(cat_dir.iterdir()):
                nm = node_pattern.match(entry.name)
                if not nm:
                    continue
                node_id = nm.group(1)
                node_name = nm.group(2)

                if entry.is_file() and entry.suffix == ".md":
                    fm = read_frontmatter(entry)
                    description = fm.get("description", "")
                    if node_id == "00.00":
                        continue
                    category.nodes.append(
                        Node(
                            id=node_id,
                            name=node_name,
                            description=description,
                        )
                    )
                elif entry.is_dir():
                    overview = entry / "overview.md"
                    if overview.exists():
                        fm = read_frontmatter(overview)
                    else:
                        fm = {}
                    description = fm.get("description", "")
                    category.nodes.append(
                        Node(
                            id=node_id,
                            name=f"{node_name}/",
                            description=description,
                            is_directory=True,
                        )
                    )

            if category.nodes:
                area.categories.append(category)

        if area.categories:
            areas.append(area)

    return areas


def render() -> str:
    """Render the index from the template."""
    import jinja2

    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader(str(index_dir)),
        keep_trailing_newline=True,
        undefined=jinja2.StrictUndefined,
    )
    areas = scan_vault()
    template = env.get_template("00.00 index.md.j2")
    return template.render(areas=areas)


def fmt(path: Path):
    subprocess.run(["nix", "fmt", "--", str(path)], check=False)


def main():
    check_mode = "--check" in sys.argv

    rendered = render()

    if check_mode:
        if not index_path.exists():
            sys.stderr.write(f"{index_path.relative_to(project_root)} does not exist.\n")
            sys.exit(1)
        tmp_path = index_path.parent / ".index-check.md"
        tmp_path.write_text(rendered)
        try:
            fmt(tmp_path)
            formatted = tmp_path.read_text()
        finally:
            tmp_path.unlink()
        existing = index_path.read_text()
        if formatted != existing:
            sys.stderr.write("docs.vault index is out of date. Run `generate-vault-index` to regenerate.\n")
            sys.exit(1)
    else:
        index_path.write_text(rendered)
        fmt(index_path)
        sys.stdout.write("docs.vault index regenerated.\n")


if __name__ == "__main__":
    main()
