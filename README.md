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

```bash
copier copy gh:jessedhillon/kit my-project
```

You'll be prompted for:

| Parameter | Description |
|-----------|-------------|
| `project_name` | Human-readable project name |
| `project_description` | Short description |
| `module_name` | Python module name (snake_case) |
| `class_prefix` | Class prefix for containers, etc. |
| `postgresql_port` | PostgreSQL port (default: 5432) |
| `web_apps` | Web applications to generate |
| `models` | Initial models to generate |

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
├── flake.nix                  # Nix devshell + formatters
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
dev
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
