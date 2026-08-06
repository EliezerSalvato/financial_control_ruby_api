# Financial Control Ruby API

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

docker compose up --build
```

On first boot, the API container runs `db:prepare` automatically via `bin/docker-entrypoint`.

Compose starts these services: `api`, `jobs`, `db`, and `mailpit`.

## Environment variables

Copy `.env.example` to `.env` and adjust values as needed.

| Variable | Description | Default |
|----------|-------------|---------|
| `POSTGRES_HOST` | PostgreSQL host | `db` |
| `POSTGRES_PORT` | PostgreSQL port | `5432` |
| `POSTGRES_USER` | Database user | `postgres` |
| `POSTGRES_PASSWORD` | Database password | `postgres` |
| `POSTGRES_DB` | Database name | `financial_control_ruby_api` |
| `SECRET_KEY_BASE` | Rails secret key base | *(required in production)* |
| `PORT` | HTTP port | `3000` |
| `RAILS_MAX_THREADS` | Puma thread count / DB pool size | `3` |
| `RAILS_LOG_LEVEL` | Log level in production | `info` |

Never commit `.env` or real secrets. Keep `.env.example` updated when adding new variables.

## Running locally

### With Docker (recommended)

```bash
docker compose up
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
docker compose exec api bin/rails console
docker compose exec api bin/rails db:migrate
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
docker compose exec api bin/rspec

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
3. Sign in — `POST /api/v1/user/authentications` → `token` in the JSON body; `refresh_token` is set as an encrypted httpOnly cookie
4. Call protected endpoints with `Authorization: Bearer <token>`
5. Refresh when expired — `PATCH /api/v1/user/session/refreshes` (reads the `refresh_token` cookie)
6. Revoke sessions — `DELETE /api/v1/user/session/revokes` (Bearer required)

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

## Troubleshooting

**API cannot connect to the database**

- Ensure the `db` service is healthy: `docker compose ps`
- Confirm `POSTGRES_*` values in `.env` match the `db` service in `docker-compose.yml`
- When running outside Docker, set `POSTGRES_HOST=localhost`

**Port 3000 already in use**

Stop the process using port 3000, or change the host mapping in `docker-compose.yml` (for example `'3001:3000'`). Setting `PORT` alone does not change the published host port.

**Emails not arriving locally**

- Confirm the `mailpit` service is up: `docker compose ps`
- Open [http://localhost:8025](http://localhost:8025)

**Bundle install fails in Docker**

```bash
docker compose down -v
docker compose build --no-cache
docker compose up
```

**Pending migrations**

```bash
docker compose exec api bin/rails db:migrate
```

**Docs page loads but endpoints are missing**

Ensure `public/openapi/spec.yml` is up to date. Redoc reads the spec from `/openapi/spec.yml`.
