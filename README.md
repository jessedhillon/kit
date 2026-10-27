# Kit

Kit is a [Copier](https://copier.readthedocs.io/) template for generating full-stack Python web applications with FastAPI backends and React/Vite frontends.

## Features

- **FastAPI** backend with automatic OpenAPI documentation
- **React 19** frontend with TypeScript, Vite, and Tailwind CSS 4
- **Dependency Injection** via `dependency-injector` with custom extensions
- **Pydantic Settings** with YAML configuration and environment-specific overrides
- **SQLAlchemy 2.0** with typed models and Alembic migrations
- **Ansible Vault** integration for encrypted secrets
- **Nix devshell** with reproducible development environment
- **process-compose** for local service orchestration
- **Pre-commit hooks** with ruff, pyright, and prettier
- **Generated TypeScript API clients** via openapi-ts

## Requirements

- [Copier](https://copier.readthedocs.io/) 9.0+
- [Nix](https://nixos.org/) with flakes enabled
- [direnv](https://direnv.net/) (recommended)

## Usage

### Generate a New Project

Kit scaffolds the Python application; the development shell (`flake.nix`) is
instantiated separately from [`nix-templates`](https://github.com/jessedhillon/nix-templates)
so the two concerns evolve independently.

```bash
copier copy gh:jessedhillon/kit my-project
cd my-project
nix flake init -t github:jessedhillon/nix-templates#dev-kit
direnv allow
install-hooks
poetry install --extras dev --extras test
```

You'll be prompted for:

| Parameter | Description |
|-----------|-------------|
| `project_name` | Human-readable project name |
| `project_description` | Short description |
| `module_name` | Python module name (snake_case) |
| `class_prefix` | Class prefix for containers, etc. |
| `postgresql_port` | PostgreSQL port (default: 5432) |
| `include_example_app` | Generate an example FastAPI web app |
| `include_example_model` | Generate an example SQLAlchemy model |
| `include_llm_scaffold` | LLM provider deps (langchain + anthropic/openai) |
| `include_streaming` | Redis + pub/sub broker deps |
| `include_auth` | JWT + bcrypt auth deps |
| `include_fixtures` | YAML fixture loader deps |

The optional-scaffold flags currently wire dependencies into `pyproject.toml`; full scaffolded code for each is a work in progress.

### Update an Existing Project

```bash
cd my-project
copier update
```

### Generated Project Structure

```
my-project/
├── config/                     # YAML configuration files
│   └── env.d/{env}/           # Environment-specific overrides
├── migrations/                 # Alembic database migrations
├── mymodule/
│   ├── cli/                   # Click CLI commands
│   ├── core/                  # DI containers, config, providers
│   ├── lib/                   # Utility libraries
│   ├── model/                 # Pydantic models
│   ├── storage/               # SQLAlchemy tables and repositories
│   └── web/{app}/             # FastAPI apps with React frontends
├── flake.nix                  # Nix devshell (from nix-templates#dev-kit)
├── pyproject.toml             # Poetry project config
└── process-compose.yaml       # Dev service orchestration
```

### Getting Started with Generated Project

```bash
cd my-project

# Enter nix shell (automatic with direnv)
direnv allow

# Install pre-commit hooks
install-hooks

# Start development services
stack-up
```

## Template Development

### Commands

```bash
# Quick syntax validation (no network)
./tests/scripts/validate-templates.sh

# Full integration test - generates fresh project and validates
./tests/scripts/test-fresh.sh

# Test template update path
./tests/scripts/init-fixture.sh  # First time only
./tests/scripts/test-update.sh
```

### Jinja Patterns

**Variable substitution:**
```jinja
{{ module_name }}
{{ class_prefix }}
{{ app.backend_port }}
```

**Loops for multi-generation:**
```jinja
{% for app in web_apps %}
case "{{ app.module_name }}":
    ...
{% endfor %}
```

**File generation from collections:**
```jinja
{% yield model from models %}{{ model.table_name }}{% endyield %}
```

**Whitespace control:**
```jinja
{%- if condition -%}   {# strips surrounding whitespace #}
```

### Adding New Template Files

1. Create `.jinja` file in `templates/`
2. Use `{{ module_name }}/` for module-relative paths
3. Use `{% yield x from collection %}` for multi-file generation
4. Run `validate-templates` to check syntax

### Template Variables

From `copier.yml`:

| Variable | Type | Description |
|----------|------|-------------|
| `project_name` | str | Human-readable project name |
| `project_description` | str | Short project description |
| `module_name` | str | Python module name |
| `class_prefix` | str | Class prefix for containers |
| `postgresql_port` | int | PostgreSQL port |
| `memcached_port` | int | Memcached port |
| `rabbitmq_port` | int | RabbitMQ port |
| `web_apps` | list | Web applications to generate |
| `models` | list | Models to generate |

Each `web_app` has: `name`, `module_name`, `class_prefix`, `backend_port`, `frontend_port`

Each `model` has: `class_name`, `table_name`

## Architecture Overview

Generated projects follow these patterns:

- **Dependency Injection**: Custom `di.py` wrapper around `dependency-injector` with `Manage[]` for resource lifecycle
- **Configuration**: Pydantic Settings with YAML sources, environment cascading, CLI overrides
- **Storage**: Functional repository pattern with Pydantic models for inputs/outputs
- **IDs**: `ShortUUIDKey` for prefixed, readable identifiers (e.g., `user$7Bj3KpVxMn...`)

See the generated `CLAUDE.md` in each project for detailed architecture documentation.

## License

MIT

## Infrastructure backports

The Propel infrastructure deltas are tracked in [BACKPORTS.md](BACKPORTS.md).
Generated projects now support `--secrets/--no-secrets`: normal boot validates
secrets immediately, while credential-free roles can defer construction until a
secret is actually accessed. Local and Test environments use file-based secrets.
Optional `template`, `vendor`, and `web` settings may be omitted.

Additional Copier switches (all off by default):

- `include_llm_scaffold`: LangGraph agent/state skeleton, compatible LangChain 1.x
  dependencies, and guidance on reducers and keeping working memory on state.
  Override `_provide_model()` or supply your own `llm.dialogue_model` provider.
- `include_session_journal`: Anthropic-backed session-journal extraction and a
  PreCompact hook. Configure `secrets.anthropic.api_key` before enabling the hook;
  set `JOURNAL_MODEL` to override its model. This option sends transcripts to the
  configured model provider when the hook runs.
- `include_tunnels`: `PROJECT-cli tunnel run NAME`, a typed Cloudflare tunnel
  secrets map, and a disabled process-compose example. Tokens travel via
  `TUNNEL_TOKEN`, never command-line arguments. Configure
  `cloudflare.tunnels.NAME.{token,hostname}` in the encrypted vault.

`tool.kit.module-name` and `tool.kit.ports` in the generated `pyproject.toml` let
`nix-templates#dev-kit` select the same project identity and default service ports.
Local environment overrides still win. Both Python and the devshell namespace
vault keys as `PROJECT/local:secrets.vault.yaml`; `VAULT_KEY_PREFIX` can override
that namespace consistently across worktrees. The Nix shell includes `cloudflared`
only when the generated tunnel feature is enabled.

Run the backport regression matrix with Copier, uv, and Python 3.13 available:

```sh
./tests/scripts/test-backports.sh
```

It renders minimal, example-free, and optional-feature projects, installs each into
an isolated temporary environment, and tests runtime boot/configuration, IDs,
optional dependencies, a fake-model agent graph, and a stubbed tunnel process.
The update check uses temporary Git repositories and preserves a local fixture
customization; it does not commit to this repository or modify another project.
