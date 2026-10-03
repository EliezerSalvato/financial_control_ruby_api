# Rails API Engineering Agent

You are a senior Ruby on Rails engineer working on a production-grade Rails API application.

# Mandatory Reading

Before making code changes:

1. Read this file (`AGENTS.md`)
2. Read only files relevant to the requested feature
3. Avoid loading unnecessary context
4. Follow the matching rules in `.agents/rules/` (see [Project rules](#project-rules))

## Project rules

This project is used with both Cursor and Claude Code. This file is the single source of instructions: Cursor reads it natively and `CLAUDE.md` only imports it (`@AGENTS.md`). Never add content to `CLAUDE.md`, and do not create `.cursor/rules/` or `.claude/rules/`.

Detailed rules live **only** in `.agents/rules/` as plain Markdown. Before working on a matching task, read the rule file:

| Rule | Read when |
|------|-----------|
| [`.agents/rules/active-record-patterns.md`](.agents/rules/active-record-patterns.md) | Editing `*::Record`, mappers, adapters or migrations (`app/models/**/*.rb` outside `app/models/core/`, `db/migrate/**/*.rb`) |
| [`.agents/rules/commit-patterns.md`](.agents/rules/commit-patterns.md) | Creating or suggesting a git commit |
| [`.agents/rules/readme.md`](.agents/rules/readme.md) | Creating or updating `README.md` |
| [`.agents/rules/terraform-naming.md`](.agents/rules/terraform-naming.md) | Writing or reviewing Terraform (`**/*.tf`, `**/*.tfvars`) |

To add a rule, create `.agents/rules/<name>.md` (plain Markdown, no tool-specific frontmatter) and add a row to this table.

## Docker (mandatory)

All project commands that depend on the app runtime **must run inside the Docker container**, never on the host.

Compose services: `api` (Rails), `jobs` (Solid Queue), `db` (PostgreSQL 18), `mailpit` (local SMTP/UI).

### Always run in the container

- Rails: `rails`, `bin/rails`
- Bundler: `bundle`, `bundle exec`
- Tests: `rspec`, `bin/rspec`, `rake`, `rubocop`, `bin/rubocop`, and similar
- Database: `rails db:*`, `rails dbconsole`
- Generators: `rails generate`
- Console: `rails console`
- CI helpers: `bin/ci`, `bin/brakeman`, `bin/bundler-audit`

### How to run

With Compose services already up (`docker compose up`):

```bash
docker compose exec api <command>
```

Examples:

```bash
docker compose exec api bin/rspec
docker compose exec api bin/rails db:migrate
docker compose exec api bundle install
docker compose exec api bin/rails console
```

Use the service name defined in `docker-compose.yml` (`api`). If `container_name` differs, still prefer `docker compose exec` / `run` with the **service** name, not the container name.

Do **not** use the `Makefile` — it is for human developers only. Always run commands via `docker compose`. The **only exception** is `make ci` (see [CI validation](#ci-validation-mandatory)).

### Allowed on the host

- `docker compose` (up, down, build, ps, logs, exec, run)
- Git and GitHub CLI (`git`, `gh`)
- Editing files in the workspace (editor / agent tools)

### Before running commands

1. Confirm containers are up (`docker compose ps`).
2. Do not install Ruby gems or run migrations directly on the host.
3. For Docker details, use the files in this repo: `Dockerfile`, `Dockerfile.dev`, `docker-compose.yml`, `docker-compose.sample.yml`, and `bin/docker-entrypoint`.

## Primary Goal

Build maintainable, scalable, secure, and testable Rails API code.

Always prioritize:

1. Maintainability
2. Readability
3. Performance
4. Security
5. Simplicity

Avoid overengineering. Do not invent `app/services/`, policy gems, or fat Active Record models when the patterns below already cover the need.

---

## Layer map

Mirror the `User` context for new bounded contexts:

| Layer | Location | Examples |
|-------|----------|----------|
| Use cases (processes) | `app/models/core/<context>/` | `Core::User::Registration` |
| Domain types | `app/models/core/<context>/` | `Core::User::Entity`, `Core::User::Email` |
| Contracts (interfaces) | `app/models/core/<context>/**/interface.rb` | `Core::User::Repository::Interface` |
| Facade | `app/models/<context>.rb` | `User` + `Solid::Context` |
| Persistence | `app/models/<context>/**/record.rb` | `User::Record`, `User::Session::Record` |
| Mappers | `app/models/<context>/**/mapper.rb` | `User::Mapper` |
| Adapters | `app/models/<context>/**/adapters/` | wired in `User::Adapters` |
| Serializers | `app/models/<context>/**/serializer.rb` | `User::Serializer` |
| HTTP | `app/controllers/api/v1/<context>/` | thin controllers only |

---

## Engineering Rules

---

### Controllers

Controllers must remain thin.

Allowed:

- params / strong params
- authentication (`authenticate_user!` / `skip_before_action`)
- request orchestration (call facade, pattern-match result)
- response rendering (via `API::V1::BaseController` helpers)
- session cookie helpers (`set_refresh_token_as_cookie`)

Forbidden:

- business logic
- SQL
- complex conditionals
- instantiating processes directly when a facade action exists
- inventing an authorization/policy layer unless explicitly requested (this app uses authentication only today)

Call domain actions through the `Solid::Context` facade (e.g. `User.register(...)`, `User.authenticate(...)`) and pattern-match on `Solid::Success` / `Solid::Failure`.

Reference: `API::V1::User::RegistrationsController`, `API::V1::User::AuthenticationsController`.

---

### Authentication

- Protected endpoints inherit `before_action :authenticate_user!` from `API::V1::BaseController`.
- Public endpoints use `skip_before_action :authenticate_user!`.
- `current_user` returns a **`Core::User::Entity`**, never a `User::Record`.
- Clients send the session token as `Authorization: Bearer <token>`.
- Refresh token is set as an encrypted HTTP-only cookie via `set_refresh_token_as_cookie` when applicable.
- Pass `request_metadata` (`ip_address`, `user_agent`) into processes that create sessions.

---

### Business logic (solid-process)

Complex business logic belongs in `ApplicationSolidProcess` subclasses under `app/models/core/`.

Pattern:

- Process: `Core::User::Registration < ApplicationSolidProcess`
- Facade: `User.register(params)` via `Solid::Context` in `app/models/user.rb`
- Controllers must not instantiate processes directly when a facade action exists

Processes must:

- have a single responsibility
- declare `deps` and `input`
- be deterministic and testable
- depend on interfaces (`Core::…::Interface`), not Active Record directly
- orchestrate with `.and_then`, `Continue()`, `Failure()`, `rollback_on_failure` as in existing processes

Infrastructure adapters live under `app/models/<context>/**/adapters/` and are wired in `<Context>::Adapters` (`solid-adapters`).

Canonical reference: `Core::User::Registration`.

---

### Models

Avoid fat Active Record models.

Prefer:

- `*::Record` for persistence (`User::Record`, `User::Session::Record`, …) — set `self.table_name`
- `Core::*::Entity` (`Data.define`) / value objects for domain data
- mappers (`User::Mapper`, …) between records and entities (`to_entity`, `to_record`, `to_errors`)
- solid-process for use cases
- adapters behind interfaces for repositories, mailer, tokens

Keep validations and normalization that belong to the use case on the process `input`, not on the Record, unless they are pure persistence constraints.

Avoid callbacks unless necessary. Never bury side effects (mail, tokens, orchestration) in Records — put them in processes.

---

### Frozen String Literal

NEVER add `# frozen_string_literal: true` to the top of the file. REMOVE it if it exists.

---

### API Design

Always:

- version APIs (`/api/v1`)
- when exposing collections, paginate with Pagy (gem is available; no in-app usage pattern yet — follow Pagy docs and keep the response envelope)
- use serializers (`jsonapi-serializer`, e.g. `User::Serializer`) wrapping entities from the facade
- use I18n for messages under `config/locales/<context>/` (e.g. `en.yml`, `pt-BR.yml`, mailer locales)
- keep OpenAPI docs in sync: add/update path files under `public/openapi/paths/`, wire them in `public/openapi/spec.yml`, update `components/` when needed (Redoc UI at `/docs`)
- OpenAPI UI is bilingual (`en` / `pt-BR`): English remains the source of truth in the modular YAML + `public/openapi/bundled.yml`; translations live in `public/openapi/locales/pt-BR.json`; regenerate with `docker compose exec api bin/openapi-localize` (writes `public/openapi/bundled.pt-BR.yml`). After changing EN prose, update the locale map (use `bin/openapi-localize --extract` / `--check pt-BR`) before regenerating
- whenever OpenAPI docs change, bump the docs version in `public/docs/index.html` (`DOCS_VERSION`) so clients reload the latest spec; keep `public/openapi/info.yml` `version` (and both bundled files) in sync when the API docs version itself changes
- return proper HTTP status codes
- keep response consistency (`render_json_with_success` / `render_json_with_error` / `render_json_with_model_errors`)
- use Zeitwerk conventions

---

### Tests

Prefer the existing style:

- **Request specs** as the primary coverage for endpoints: `spec/requests/api/v1/<context>/...`
- **FactoryBot** factories under `spec/factories/<context>/`, with `class: "...::Record"`
- Thin **Record specs** only when persistence behavior needs unit coverage (`spec/models/.../record_spec.rb`)
- Reuse helpers in `spec/support/` (e.g. auth helpers)

**Line coverage must stay at 100%.** SimpleCov enforces `minimum_coverage line: 100` in `spec/spec_helper.rb`. After adding or changing code, run the full suite in Docker (`docker compose exec api bin/rspec`) and cover every missed line before finishing. Do not lower the line threshold. Prefer request specs first; add a focused process/model example only when SimpleCov still reports a missed line.

Do not invent a parallel test stack. Mirror an existing request spec when adding an endpoint.

---

### CI validation (mandatory)

After **any** change to the project (code, specs, config, locales, OpenAPI, migrations, etc.), run the full CI pipeline from the host before finishing:

```bash
make ci
```

It runs `bin/ci` inside the `api` container (setup, RuboCop, `i18n-tasks health`, bundler-audit, Brakeman, and RSpec with 100% line coverage — see `config/ci.rb`).

- If any step fails, fix the cause and re-run `make ci` until it passes.
- Never bypass a failing step by disabling cops, adding Brakeman ignores, lowering coverage, or skipping specs, unless the user explicitly approves it.
- If a failure is unrelated to your change (e.g. a new advisory from `bundler-audit`), report it to the user instead of silently working around it.
- Do not report a task as done while `make ci` is failing; state clearly which step failed and why.

---

## Environment Policy

- All investigations, bug reproductions, Rails commands, and validation of changes must be performed using the `test` environment unless I explicitly request a different environment.
- Never use the `development` database to reproduce bugs or validate changes.
- The `development` database may only be used to run database migrations.
- Always prefer commands with `RAILS_ENV=test`.

---

### Commits

Only create a git commit when the user explicitly asks. When committing, follow `.agents/rules/commit-patterns.md` (Conventional Commits).

---

## Before Writing Code

Ask yourself:

1. Which rules in `.agents/rules/` apply?
2. Which layer owns this change (see Layer map)?
3. Which existing files are the best reference to mirror?
4. Are there security concerns (auth, tokens, cookies)?
5. Are there performance concerns?
6. Does this require request specs / factories?
7. Will the full suite still report 100% line coverage?
8. Does this require OpenAPI / I18n updates? If OpenAPI changed, was the docs version bumped (`public/docs/index.html` `DOCS_VERSION`), `locales/pt-BR.json` updated, and `bin/openapi-localize` re-run?
9. Did the user ask for a commit?

Only then implement. After implementing, run `make ci` and fix any failure before finishing.
