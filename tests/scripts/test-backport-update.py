import atexit
import io
import shutil
import subprocess
import tarfile
import tempfile
from pathlib import Path

repo = Path(__file__).resolve().parents[2]
base = Path(tempfile.mkdtemp(prefix="kit-update-check-"))
atexit.register(shutil.rmtree, base)
source = base / "source"
source.mkdir()
target = base / "project"


def run(*args, cwd=None):
    return subprocess.run(args, cwd=cwd, check=True, text=True, capture_output=True).stdout.strip()


archive = subprocess.run(
    ["git", "-C", str(repo), "archive", "HEAD"], check=True, capture_output=True
).stdout
with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
    tar.extractall(source, filter="data")
run("git", "init", "-q", cwd=source)
for key, value in [("user.email", "fixture@example.test"), ("user.name", "Template fixture")]:
    run("git", "config", key, value, cwd=source)
run("git", "add", ".", cwd=source)
run("git", "commit", "-qm", "baseline", cwd=source)
run(
    "copier",
    "copy",
    "--trust",
    "--defaults",
    "--vcs-ref",
    "HEAD",
    "--data-file",
    str(repo / "tests/answers.yml"),
    str(source),
    str(target),
)
run("git", "init", "-q", cwd=target)
for key, value in [("user.email", "fixture@example.test"), ("user.name", "Template fixture")]:
    run("git", "config", key, value, cwd=target)
custom = target / "config/storage.yaml"
custom.write_text(custom.read_text() + "\n# local fixture customization\n")
run("git", "add", ".", cwd=target)
run("git", "commit", "-qm", "generated with local customization", cwd=target)
shutil.rmtree(source / "templates")
shutil.copytree(repo / "templates", source / "templates", symlinks=True)
shutil.copy2(repo / "copier.yml", source / "copier.yml")
run("git", "add", "-A", cwd=source)
run("git", "commit", "--allow-empty", "-qm", "backports", cwd=source)
run("copier", "update", "--trust", "--defaults", "--vcs-ref", "HEAD", cwd=target)
assert not list(target.rglob("*.rej"))
assert "# local fixture customization" in custom.read_text()
assert "def unsafe" in (target / "testproject/model/id.py").read_text()
assert "uvicorn[standard]" in (target / "pyproject.toml").read_text()
assert "--no-secrets" in (target / "testproject/cli/__main__.py").read_text()
print("Copier update passed; local customization retained")
