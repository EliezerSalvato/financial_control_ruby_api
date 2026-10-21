---
name: add-api-endpoint
description: "Adds a versioned JSON API endpoint across the facade, Core process, thin controller, request spec, locales, and OpenAPI. Use when the user asks to add, change, or expose an HTTP endpoint, route, or API action."
---

# Add an API endpoint

Follow `AGENTS.md`. Mirror the closest existing endpoint. Small action: `API::V1::User::Email::ConfirmationResendsController` and `Core::User::Email::Confirmation::Resend`. Full use case: `API::V1::User::RegistrationsController` and `Core::User::Registration`.

Read `.agents/rules/active-record-patterns.md` before editing a Record, mapper, adapter, or migration.

## Steps

1. Put the use case in `app/models/core/<context>/` as an `ApplicationSolidProcess`: one responsibility, `deps`, `input`, `.and_then`, `Continue()`, `Failure()`, `rollback_on_failure`. Depend on `Core::…::Interface`, not Active Record.
2. Expose it on the context facade (`User` or the matching `Solid::Context` module). The controller calls the facade, never the process class.
3. Add a thin controller under `app/controllers/api/v1/<context>/`. Allowed there: strong params, `skip_before_action :authenticate_user!` for public routes, pattern-match `Solid::Success` / `Solid::Failure`, render via `API::V1::BaseController`, and `set_refresh_token_as_cookie` when a session is created. Pass `request_metadata` (`ip_address`, `user_agent`) when the process creates a session.
4. Register the route inside `namespace :api` / `namespace :v1` in `config/routes.rb`.
5. Add a request spec at `spec/requests/api/v1/<context>/...`. Add a factory under `spec/factories/<context>/` with `class: "...::Record"` only when a new record is required.
6. Add message keys in `config/locales/<context>/en.yml` and `config/locales/<context>/pt-BR.yml`.
7. Add the OpenAPI path under `public/openapi/paths/`, wire it in `public/openapi/spec.yml`, and update `public/openapi/components/` when the shape is new. English YAML is the source of truth. Update `public/openapi/locales/pt-BR.json`, then run `docker compose exec api bin/openapi-localize`. Bump `DOCS_VERSION` in `public/docs/index.html`. When the API docs version itself changes, keep `public/openapi/info.yml` `version` and both bundled files in sync.
8. Run runtime commands inside the `api` container (`docker compose exec api ...`) with `RAILS_ENV=test`, except a development migration the user explicitly requested.
9. Run `make ci` and fix every failure it reports. Leave the work uncommitted unless the user asked for a commit.

Do not add `app/services/`, an authorization layer, `# frozen_string_literal: true`, or a process spec when the request spec already covers the new lines.
