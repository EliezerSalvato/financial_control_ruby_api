# Financial Control Ruby API

Rails JSON API for personal financial control: accounts, credit cards, transactions, monthly statements, settlements, and notifications.

Frontend: [financial_control_vue](https://github.com/EliezerSalvato/financial_control_vue)

## Tech stack

<table>
  <tr>
    <td align="left">
      <img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/ruby/ruby-original.svg" alt="Ruby" width="48" height="48" /><br />
      <strong>Ruby</strong><br />
      3.4.5
    </td>
    <td align="left">
      <img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/rails/rails-plain-wordmark.svg" alt="Rails" width="48" height="48" /><br />
      <strong>Rails</strong><br />
      8.1
    </td>
    <td align="left">
      <img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/postgresql/postgresql-original.svg" alt="PostgreSQL" width="48" height="48" /><br />
      <strong>PostgreSQL</strong><br />
      18
    </td>
  </tr>
</table>

| Layer | Technology |
|-------|------------|
| App server | Puma 8 |
| Auth | bcrypt + session tokens + refresh tokens |
| Background jobs | Solid Queue + Mission Control Jobs |
| Serialization | jsonapi-serializer |
| Pagination | Pagy |
| Business logic | solid-process, solid-adapters |
| Auditing | paper_trail |
| Security | rack-attack, rack-cors |
| Testing | RSpec, Factory Bot, Faker, SimpleCov |
| Linting & security | RuboCop (Omakase), Brakeman, bundler-audit |
| Containers | Docker, Docker Compose |
| Local email | Mailpit |
| CI | GitHub Actions |
| API docs | OpenAPI 3.1 + Redoc |

## Requirements

- [Docker](https://docs.docker.com/get-docker/) and [Docker Compose](https://docs.docker.com/compose/)
- Ruby 3.4.5 (only if running outside Docker)

## Setup instructions

```bash
git clone <repository-url>
cd financial_control_ruby_api

cp docker-compose.sample.yml docker-compose.yml
cp .env.example .env

make setup
make up
```

`make setup` builds the images, installs gems, and runs `db:prepare`. `make up` starts `api`, `jobs`, `db`, and `mailpit`. The `api` and `jobs` containers also run `db:prepare` on boot.

## Environment variables

Copy `.env.example` to `.env` and adjust values as needed.

| Variable | Description | Default |
|----------|-------------|---------|
| `POSTGRES_HOST` | PostgreSQL host | `db` |
| `POSTGRES_PORT` | PostgreSQL port | `5432` |
| `POSTGRES_USER` | Database user | `postgres` |
| `POSTGRES_PASSWORD` | Database password | `postgres` |
| `POSTGRES_DB` | Rails database name prefix (`{name}_development` / `{name}_test`; production uses the name as-is) | `financial_control_ruby_api` |
| `SECRET_KEY_BASE` | Rails secret key base | *(required in production)* |
| `PORT` | HTTP port | `3000` |
| `RAILS_MAX_THREADS` | Puma thread count / DB pool size | `3` |
| `RAILS_LOG_LEVEL` | Log level in production | `info` |
| `FRONTEND_URL` | Public frontend origin used in mailer links | `http://localhost:5173` |
| `CORS_ORIGINS` | Comma-separated allowed CORS / Action Cable origins | `http://localhost:5173` |
| `JOB_CONCURRENCY` | Solid Queue worker processes | `3` |
| `MISSION_CONTROL_HTTP_BASIC_AUTH_USER` | Mission Control username | `admin` |
| `MISSION_CONTROL_HTTP_BASIC_AUTH_PASSWORD` | Mission Control password | `secret` |

Never commit `.env` or real secrets. Keep `.env.example` updated when adding new variables.

## Running locally

### With Docker (recommended)

```bash
make up
```

| Resource | URL |
|----------|-----|
| API | [http://localhost:3000](http://localhost:3000) |
| API docs (Redoc) | [http://localhost:3000/docs](http://localhost:3000/docs) |
| Mission Control Jobs | [http://localhost:3000/jobs](http://localhost:3000/jobs) |
| Mailpit UI | [http://localhost:8025](http://localhost:8025) |

Health check:

```bash
curl http://localhost:3000/up
```

Run Rails commands inside the container:

```bash
make console
make migrate
```

Solid Queue workers run in the `jobs` service. Mission Control uses HTTP basic auth (`MISSION_CONTROL_HTTP_BASIC_AUTH_*`).

Development mail goes to Mailpit (`mailpit:1025` SMTP inside Compose).

### Without Docker

```bash
bundle install
bin/rails db:prepare
bin/rails server
```

Set `POSTGRES_HOST=localhost` in `.env` and ensure PostgreSQL is running locally. For background jobs and email outside Compose, run Solid Queue and a local SMTP catcher separately.

## Running tests

```bash
# Docker
make test

# Local
bin/rspec
```

## API documentation

Interactive docs are served by Redoc at:

| Resource | URL |
|----------|-----|
| Docs UI | [http://localhost:3000/docs](http://localhost:3000/docs) |

Source files:

- `public/docs/index.html` — Redoc page
- `public/openapi/spec.yml` — OpenAPI specification

Update the spec file when adding or changing endpoints.

### Authentication

Protected endpoints require a Bearer session token:

```http
Authorization: Bearer <token>
```

1. Register — `POST /api/v1/user/registrations`
2. Confirm email — `POST /api/v1/user/email/confirmations` (token from email; inspect in Mailpit locally)
3. Sign in — `POST /api/v1/user/authentications` → `token` in the JSON body; `refresh_token` is set as an encrypted httpOnly cookie (`SameSite=Lax`; `Secure` in production). Revokes previous refresh sessions
4. Call protected endpoints with `Authorization: Bearer <token>`
5. Refresh when expired — `PATCH /api/v1/user/session/refreshes` (reads the `refresh_token` cookie)
6. Revoke sessions — `DELETE /api/v1/user/session/revokes` (Bearer required; does not clear the cookie)

Password change, password reset (`PATCH`), and email change also revoke all refresh sessions. The current Bearer token remains valid until it expires.

| Token | Lifetime |
|-------|----------|
| Session (`token`) | 15 minutes |
| Refresh cookie (`remember_me: true`) | 30 days |
| Refresh cookie (without `remember_me`) | session cookie / 1 day server-side |
| Email confirmation | 24 hours |
| Password reset | 15 minutes |

### User endpoints (`/api/v1/user`)

| Method | Path | Auth |
|--------|------|------|
| POST | `/api/v1/user/registrations` | Public |
| POST | `/api/v1/user/authentications` | Public |
| POST | `/api/v1/user/email/confirmations` | Public |
| POST | `/api/v1/user/password/resets` | Public |
| PATCH | `/api/v1/user/password/resets` | Public |
| PATCH | `/api/v1/user/session/refreshes` | Public |
| PATCH | `/api/v1/user/profiles` | Bearer |
| DELETE | `/api/v1/user/accounts` | Bearer |
| PATCH | `/api/v1/user/email/changes` | Bearer |
| PATCH | `/api/v1/user/password/changes` | Bearer |
| DELETE | `/api/v1/user/session/revokes` | Bearer |

### Domain endpoints (`/api/v1`)

All require Bearer. See the OpenAPI spec for request and response schemas.

| Resource | Paths |
|----------|-------|
| Tags | `GET, POST /tags` · `GET, PATCH, DELETE /tags/{id}` |
| Categories | `GET, POST /categories` · `GET, PATCH, DELETE /categories/{id}` |
| Institutions | `GET, POST /institutions` · `GET, PATCH, DELETE /institutions/{id}` |
| Accounts | `GET, POST /accounts` · `GET, PATCH, DELETE /accounts/{id}` |
| Credit cards | `GET, POST /credit_cards` · `GET, PATCH, DELETE /credit_cards/{id}` · `GET /credit_cards/invoice_settlements` |
| Transactions | `GET, POST /transactions` · `GET, PATCH, DELETE /transactions/{id}` · `GET /transactions/settled` · `POST /transactions/{id}/cancel` · `POST /transactions/{id}/recurrences` |
| Monthly statements | `GET /monthly_statements` · `GET /monthly_statements/transfers` |
| Monthly statuses | `GET, PATCH /monthly_statuses` |
| Settlements | `POST /settlements/processing` |
| Notifications | `GET /notifications` · `GET /notifications/{id}` · `POST /notifications/{id}/read` · `POST /notifications/read_all` |

### Locale

Authenticated requests use `configs.locale` (`en` or `pt-BR`). Cookie and `Accept-Language` are ignored.

Unauthenticated requests use, in order: `locale` cookie, `Accept-Language`, then English. The API reads that cookie; it does not set it.

On sign in, a valid `locale` cookie that differs from `configs.locale` updates the stored locale.

### Rate limiting

| Scope | Limit |
|-------|-------|
| General (all HTTP except `/up` and `/cable`, any method) | 300 requests / 5 minutes per IP, hashed Bearer token, and user id |
| Login, registration, password reset, session refresh | 10 requests / 1 minute |

Throttled responses are **429** with Rack::Attack's default `text/plain` body (`Retry later`), not the JSON error envelope. Every OpenAPI operation documents **429**.

### WebSockets

Action Cable is mounted at `/cable`. Authenticate with `?token=<session token>` or `Authorization: Bearer <token>`. The handshake is rejected when the token is missing or invalid, or when the user is inactive.

| Channel | Params | Payload |
|---------|--------|---------|
| `MonthlyStatusChannel` | `month`, `year` | `{ processing, last_processed_at }` on subscribe and when processing changes. Subscription is rejected if that month row does not exist. |
| `NotificationChannel` | none | `{ kind, notification, unread_count }` for a single item, or `{ kind, unread_count }` for a batch |

See the OpenAPI description for payload examples and notification kinds.

## Deployment

There is no bundled hosting target. For production:

- Set a strong `SECRET_KEY_BASE`.
- Set `CORS_ORIGINS` and `FRONTEND_URL` to the real frontend origin(s).
- Set `MISSION_CONTROL_HTTP_BASIC_AUTH_USER` and `MISSION_CONTROL_HTTP_BASIC_AUTH_PASSWORD`.
- Production forces SSL and marks the refresh cookie `Secure`.
- Allowed `Host` values come from Rails credentials (`hosts`). `/up`, `/docs`, `/openapi`, and `/jobs` skip host authorization.
- Run the `api` process and a Solid Queue worker (`jobs` / `bin/jobs`) against PostgreSQL.
- Production recurring jobs (`config/recurring.yml`, timezone `America/Sao_Paulo`) settle open months daily at 03:00, close previous open months at 05:00 on the 1st, and clear finished Solid Queue jobs hourly at minute 12.
- Point SMTP at a real mailer; Mailpit is local-only.

## Troubleshooting

**API cannot connect to the database**

- Ensure the `db` service is healthy: `make ps`
- `POSTGRES_USER` and `POSTGRES_PASSWORD` in `.env` must match the `db` service
- Rails uses `POSTGRES_DB` from `.env` as a name prefix (`financial_control_ruby_api_development`). The Compose `db` service bootstraps a database named `postgres`; that is expected
- When running outside Docker, set `POSTGRES_HOST=localhost`

**Port 3000 already in use**

Stop the process using port 3000, or change the host mapping in `docker-compose.yml` (for example `'3001:3000'`). Setting `PORT` alone does not change the published host port.

**Emails not arriving locally**

- Confirm the `mailpit` service is up: `make ps`
- Open [http://localhost:8025](http://localhost:8025)

**Bundle install fails in Docker**

```bash
make clean
make build
make up
```

**Pending migrations**

```bash
make migrate
```

**Docs page loads but endpoints are missing**

Ensure `public/openapi/spec.yml` is up to date. Redoc reads the spec from `/openapi/spec.yml?v=...`. After changing the spec, bump that query param in `public/docs/index.html` and the `version` in `public/openapi/info.yml`.
