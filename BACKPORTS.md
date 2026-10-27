# Propel infrastructure backports

Implemented locally from Propel's `10.06 template deltas` vault document.
These are working-tree changes, not a claim that a release has been published.
Flaneur has not been migrated to the updated scaffold.

| Vault entry | Implementation |
| --- | --- |
| Settings None-shadowing | Unowned fields raise `KeyError`; explicit values still take precedence. |
| Test file secrets | Local/Test default to the file config root. |
| Nullable settings sections | Template/vendor/web sections are optional. |
| Optional Google imports | TYPE_CHECKING and lazy imports; third-party typing exclusions. |
| Agent-doc hook Python | Uses the repository venv and skips cleanly without one. |
| YAML environment expansion | Supports `$VAR`, `${VAR}`, `${VAR:-default}`, including colon-containing defaults. Preserves Propel's documented empty-value semantics. |
| Journal/vault scope | Shared agent instructions and journal guidance. |
| FastAPI conventions | Unprefixed URL IDs, converters/loaders, error surfacing. |
| ShortUUID validation | Validated `key=`, explicit `unsafe()` ORM hydration. |
| ShortUUID separator | `.` for displayed IDs; stored payloads unchanged. |
| Uvicorn standard | Standard extra supplies native reload/parser/event-loop dependencies. |
| 1Password key installation | dev-kit installer and noninteractive-safe startup; local env loads before flake. |
| Session extraction | Separate opt-in hook, CLI script, and Anthropic secret/dependency. |
| Agent framework | Optional agent/state skeleton and concurrency/working-memory guidance. |
| Vault-key whitespace | Installer strips CR/LF from fetched single-line keys. |
| PostgreSQL socket/readiness | `-k PGHOST`, foreground service, real `psql` readiness query. |
| Stack lifecycle | dev-kit `stack-up --keep-project`. |
| Weekly retrospective | Generic dated ritual with evidence analysis and editorial pass. |
| Tunnel wrapper | Optional CLI/schema/example; corrected original argv token exposure. |
| Keyring namespace | Shared project prefix, with explicit override and stable worktree identity. |
| Lazy secrets | Singleton-backed deferred loading plus default eager validation gate. |

The Nix changes live in the sibling `nix-templates/dev-kit` template; they are
intentionally not duplicated into this Copier template. Project metadata bridges
the two templates' module names, ports, and optional tunnel dependency.

Generation/runtime validation also uncovered and corrected three related issues:
missing `sql-formatter` runtime dependency, incompatible old `uuid-utils` pin when
LangGraph 1.1 is enabled, and invalid empty imports/blocks when examples are disabled.
The agent skeleton now has a usable default for optional node-name prefixes.

All new integrations remain opt-in. No customer models, banking integrations,
provider credentials, deployment resources, dated retros, or Propel data were copied.
