"""Run against a rendered project, never a developer's database or keyring.

KIT_RENDERED_ROOT=/tmp/render PYTHONPATH=/tmp/render /tmp/venv/bin/pytest tests/runtime
"""

import asyncio
import importlib
import json
import os
import shutil
import sys
from pathlib import Path

import pydantic as p
import pytest

ROOT = Path(os.environ["KIT_RENDERED_ROOT"])
sys.path.insert(0, str(ROOT))
MODULE = os.environ.get("KIT_TEST_MODULE", "testproject")
OPTIONAL = os.environ.get("KIT_TEST_OPTIONAL") == "1"


def load(path):
    return importlib.import_module(f"{MODULE}.{path}")


@pytest.fixture
def config_root(tmp_path, monkeypatch):
    monkeypatch.delenv("PGPORT", raising=False)
    root = tmp_path / "config"
    shutil.copytree(ROOT / "config", root)
    for name in ("vendor", "web", "template"):
        (root / f"{name}.yaml").unlink(missing_ok=True)
    # Avoid filesystem handlers and any dependency on the developer's .state.
    (root / "logging.yaml").write_text(
        "version: 1\nformatters: {}\nhandlers: {}\nloggers: {}\nroot: {level: INFO, handlers: []}\n"
    )
    return p.FileUrl(root.as_uri())


def test_settings_fallthrough_cli_override_and_optional_sections(config_root, monkeypatch):
    settings = load("core.config").Settings
    env = load("model").DeploymentEnvironment.Test
    base = settings(root=config_root, env=env, override=())
    assert base.storage.persistent.postgresql.port == 15432
    assert base.vendor is base.web is base.template is None
    monkeypatch.setenv("PGPORT", "6544")
    assert (
        settings(root=config_root, env=env, override=()).storage.persistent.postgresql.port == 6544
    )
    overridden = settings(
        root=config_root, env=env, override=("storage.persistent.postgresql.port=6543",)
    )
    assert overridden.storage.persistent.postgresql.port == 6543


@pytest.mark.parametrize(
    "value,expected",
    [
        ("${KIT_TEST_UNSET:-file:///tmp/path}", "file:///tmp/path"),
        ("$KIT_TEST_UNSET", "$KIT_TEST_UNSET"),
        ("${KIT_TEST_UNSET:-}", ""),
    ],
)
def test_environment_expansion(value, expected, monkeypatch):
    monkeypatch.delenv("KIT_TEST_UNSET", raising=False)
    assert load("lib.util").expand_env_vars(value) == expected


def test_yaml_environment_defaults(config_root, monkeypatch):
    root = Path(config_root.path)
    (root / "storage.yaml").write_text(
        "persistent:\n  postgresql:\n    database: fixture\n    port: ${KIT_TEST_PORT:-6543}\n"
    )
    monkeypatch.delenv("KIT_TEST_PORT", raising=False)
    settings = load("core.config").Settings(
        root=config_root, env=load("model").DeploymentEnvironment.Test, override=()
    )
    assert settings.storage.persistent.postgresql.port == 6543


def test_shortuuid_validation_unsafe_and_orm_hydration():
    class Key(load("model.id").ShortUUIDKey, prefix="test"):
        pass

    key = Key()
    assert str(key).startswith("test.")
    assert Key(key=key.key) == Key(str(key)) == key
    for invalid in ("short", "0" * 22):
        with pytest.raises(ValueError):
            Key(key=invalid)
    assert Key.unsafe("trusted").key == "trusted"
    mapper = load("storage.type").ShortUUIDKeyType(Key)
    assert mapper.process_bind_param(key, None) == key.key
    assert mapper.process_result_value(key.key, None) == key


def test_google_is_optional_and_container_imports_without_google():
    assert importlib.util.find_spec("googleapiclient") is None
    assert load("core").__dict__[os.environ.get("KIT_TEST_CLASS", "Test") + "Container"]


def test_lazy_secrets_and_fail_fast_gate(config_root, monkeypatch):
    model = load("model")
    container_module = load(f"core.container.{MODULE}")
    cls = getattr(container_module, os.environ.get("KIT_TEST_CLASS", "Test") + "Container")
    calls = []

    def secret_loader(env, root):
        calls.append((env, root))
        raise RuntimeError("vault unavailable")

    monkeypatch.setattr(container_module, "load_secrets", secret_loader)
    container = cls()
    cls.boot(
        container,
        debug=False,
        env=model.DeploymentEnvironment.Test,
        config_root=config_root,
        require_secrets=False,
    )
    assert calls == []
    with pytest.raises(RuntimeError, match="vault unavailable"):
        container.secrets()
    assert calls[0][1] == config_root  # Test uses local files, not an aws:// root.
    eager = cls()
    with pytest.raises(RuntimeError, match="vault unavailable"):
        cls.boot(eager, debug=False, env=model.DeploymentEnvironment.Local, config_root=config_root)
    container.unwire()
    eager.unwire()


def test_secrets_source_falls_through_and_namespaces_keyring(tmp_path, monkeypatch):
    source = load("core.config.source")

    class SecretSettings(load("core.config.base").BaseSecrets):
        root: p.AnyUrl
        env: load("model").DeploymentEnvironment
        value: str | None = None

    instance = source.AnsibleVaultSecretsSource(SecretSettings)
    instance.__dict__["secrets"] = {"owned": "yes"}
    with pytest.raises(KeyError):
        instance.get_field_value(None, "value")
    assert instance.get_field_value(None, "owned") == ("yes", "owned", False)


def test_minimal_and_optional_generation_boundaries():
    hooks = json.loads((ROOT / ".claude/settings.json").read_text())["hooks"]
    assert ("PreCompact" in hooks) == OPTIONAL
    assert (ROOT / MODULE / "llm/agent/base.py").exists() == OPTIONAL
    assert (ROOT / MODULE / "cli/tunnel.py").exists() == OPTIONAL
    assert (ROOT / MODULE / "cli/script/extract_session_journal.py").exists() == OPTIONAL


@pytest.mark.skipif(not OPTIONAL, reason="optional scaffold disabled")
def test_agent_graph_runs_without_external_model_calls():
    from langchain_core.language_models.fake_chat_models import FakeListChatModel
    from langchain_core.messages import HumanMessage, SystemMessage

    agent = load("llm.agent")

    class Example(agent.BaseAgent[agent.AgentState]):
        def _provide_model(self):
            return FakeListChatModel(responses=["hello"])

        def system_prompt(self, state):
            return SystemMessage(content="test")

    graph = Example().compile()
    result = asyncio.run(graph.ainvoke({"messages": [HumanMessage(content="hi")]}))
    assert result["messages"][-1].content == "hello"


@pytest.mark.skipif(not OPTIONAL, reason="optional scaffold disabled")
def test_tunnel_keeps_token_out_of_argv(monkeypatch):
    tunnel = load("cli.tunnel")
    calls = []

    class Process:
        def __init__(self, args, **kwargs):
            calls.append((args, kwargs))

        def wait(self):
            return 0

    monkeypatch.setattr(tunnel.subprocess, "Popen", Process)
    monkeypatch.setattr(tunnel.signal, "signal", lambda *args: None)
    fn = tunnel.run.callback
    while hasattr(fn, "__wrapped__"):
        fn = fn.__wrapped__
    with pytest.raises(SystemExit) as exit:
        fn(
            name="example",
            cloudflare_secrets={
                "tunnels": {"example": {"token": "fixture-secret", "hostname": "example.test"}}
            },
        )
    assert exit.value.code == 0
    assert calls[0][0] == ["cloudflared", "tunnel", "run"]
    assert calls[0][1]["env"]["TUNNEL_TOKEN"] == "fixture-secret"


@pytest.mark.parametrize("prefix", [None, "custom-project"])
def test_vault_uses_project_prefix_without_real_keyring(tmp_path, monkeypatch, prefix):
    from types import SimpleNamespace

    source = load("core.config.source")
    env = load("model").DeploymentEnvironment.Local

    class Secrets(load("core.config.base").BaseSecrets):
        root: p.AnyUrl
        env: load("model").DeploymentEnvironment

    if prefix is None:
        monkeypatch.delenv("VAULT_KEY_PREFIX", raising=False)
    else:
        monkeypatch.setenv("VAULT_KEY_PREFIX", prefix)
    (tmp_path / "secrets.vault.yaml").write_text("fixture encrypted vault")
    names = []

    def search(name):
        names.append(name)
        return SimpleNamespace(data="fixture-key")

    monkeypatch.setattr(source, "keyctl", SimpleNamespace(search=search))
    monkeypatch.setattr(
        source, "VaultLib", lambda **kwargs: SimpleNamespace(decrypt=lambda text: "owned: value")
    )
    instance = source.AnsibleVaultSecretsSource(Secrets)
    instance._set_current_state({"root": p.FileUrl(tmp_path.as_uri()), "env": env})
    assert instance.secrets == {"owned": "value"}
    assert names == [f"{prefix or MODULE}/local:secrets.vault.yaml"]


@pytest.mark.skipif(not OPTIONAL, reason="optional scaffold disabled")
def test_session_extractor_respects_compaction_and_skips_tool_payloads(tmp_path):
    journal = load("cli.script.extract_session_journal")
    records = [
        {"type": "user", "message": {"content": "old context"}},
        {"type": "user", "message": {"content": journal.compaction_marker}},
        {"type": "user", "message": {"content": "keep this decision"}},
        {
            "type": "assistant",
            "message": {
                "content": [
                    {"type": "tool_use", "input": {"secret": "must not be copied"}},
                    {"type": "text", "text": "keep this response"},
                ]
            },
        },
    ]
    path = tmp_path / "session.jsonl"
    path.write_text("\n".join(map(json.dumps, records)))
    extracted = journal.extract_conversation(path)
    assert "keep this decision" in extracted and "keep this response" in extracted
    assert "old context" not in extracted and "must not be copied" not in extracted
