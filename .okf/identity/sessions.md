---
type: Process
title: Sessions
description: A short signed Bearer token plus a hashed refresh cookie; credential changes revoke refresh sessions only.
tags: [auth]
generated:
  by: cursor-agent/grok-4.7
  at: 2026-10-21T13:50:00Z
sources:
  - id: token
    title: Core::User::Token lifetimes
    resource: app/models/core/user/token.rb
  - id: authentication
    title: Core::User::Authentication
    resource: app/models/core/user/authentication.rb
  - id: locale
    title: API::V1::BaseController#resolve_locale
    resource: app/controllers/api/v1/base_controller.rb
---

# Overview

Sign-in requires a verified, active user. It revokes every existing refresh session for that user, stores a new refresh-token digest, and returns a Bearer token.[^authentication] The Bearer token is a Rails `signed_id` (`purpose: :session_token`). It is not a row. The refresh token is `SecureRandom.urlsafe_base64(64)`; only its SHA-256 digest is stored on `user_sessions`, with `ip_address` and `user_agent`.

| Token | Lifetime | Where it lives |
|-------|----------|----------------|
| Session Bearer | 15 minutes | `Authorization` header; stateless signed id |
| Refresh with `remember_me` | 30 days | Encrypted httpOnly cookie, `SameSite=Lax`, `Secure` in production |
| Refresh without `remember_me` | 1 day server-side | Session cookie |
| Email confirmation | 24 hours | Digest on `user_email_confirmations` |
| Password reset | 15 minutes | Digest on `user_password_resets` |[^token]

# What revocation does

Password change, password reset, and email change call `revoke_all_by` and delete refresh rows. They do not invalidate a Bearer token that was already issued; that token verifies until its signed expiry. `DELETE /api/v1/user/session/revokes` does the same to refresh rows and does not clear the cookie. A later `PATCH /api/v1/user/session/refreshes` fails because the digest is gone. Refresh rotates the cookie.

# Locale

An authenticated request resolves locale from `users.configs["locale"]` (`en` or `pt-BR`). The `locale` cookie and `Accept-Language` are ignored once a user is loaded.[^locale] Unauthenticated requests use the cookie, then `Accept-Language`, then English. The API reads the cookie and does not set it. On sign-in, a valid `locale` cookie that differs from the stored locale updates `configs`.

Action Cable at `/cable` accepts the same Bearer token as `?token=` or `Authorization`. A missing token, an invalid token, or an inactive user is rejected.

See the [HTTP surface](/delivery/http-surface.md) for how these tokens sit on routes.

[^token]: Lifetimes are constants on `Core::User::Token`, `Core::User::Email`, and `Core::User::Password`.
[^authentication]: `Core::User::Authentication` checks the password, verified email, and `active`, syncs locale, then revokes previous refresh sessions before inserting the new one.
[^locale]: `API::V1::BaseController#resolve_locale` returns `Core::User::Locale.resolve` from the entity when `current_user` is present.
