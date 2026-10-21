---
type: Decision
title: HTTP surface
description: Versioned JSON under /api/v1, Bearer auth, stored locale, and Rack::Attack limits.
resource: https://api.financialcontrol.app.br/
tags: [auth]
generated:
  by: cursor-agent/grok-4.7
  at: 2026-10-21T13:50:00Z
sources:
  - id: routes
    title: Rails routes
    resource: config/routes.rb
  - id: rack-attack
    title: Rack::Attack limits
    resource: config/initializers/rack_attack.rb
---

# Overview

Clients talk to `/api/v1`. Protected routes inherit `authenticate_user!` and expect `Authorization: Bearer`, the [session](/identity/sessions.md) token. Public routes are registration, authentication, email confirmation and resend, password reset, and session refresh. Responses use `jsonapi-serializer` around entities returned by the facade. Collections paginate with Pagy. Errors use the shared JSON envelope, except throttling.

The resource groups are tags, categories, institutions, accounts, credit cards (including invoice settlements), transactions (cancel, recurrences, settled list, imports, import rules), monthly statements and transfers, goals and targets, one monthly status, settlement processing, and notifications.[^routes] There is a single API version. A second version would be a new namespace, not a flag on these controllers.

# Locale and limits

Authenticated locale comes from the user record, as [sessions](/identity/sessions.md) describe. Rack::Attack applies three general throttles — per IP, per hashed Bearer token, and per user id — of 300 requests per 5 minutes, skipping `/up` and `/cable`. Login, registration, confirmation resend, password reset, and session refresh are also limited to 10 requests per minute, keyed by IP and by a hash of the email or token.[^rack-attack] A throttled response is **429** with Rack::Attack's `text/plain` body `Retry later`, not the JSON error envelope.

OpenAPI 3.1 is the contract clients read at `/docs`. English YAML under `public/openapi/` is the source; `public/openapi/locales/pt-BR.json` translates human-readable strings into `bundled.pt-BR.yml`. A docs change bumps `DOCS_VERSION` so browsers drop a cached spec.

The [hexagonal boundary](/architecture/hexagonal-boundary.md) is why these controllers stay thin: every mutation above is a facade call.

[^routes]: `config/routes.rb` namespace `api/v1`.
[^rack-attack]: `GENERAL_REQUEST_LIMIT` / `AUTH_ENDPOINT_LIMIT` in `config/initializers/rack_attack.rb`.
