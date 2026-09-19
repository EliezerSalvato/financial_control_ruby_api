#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
COMPOSE_FILE="${ROOT_DIR}/docker-compose.production.yml"
COMPOSE=(docker compose -f "${COMPOSE_FILE}")

if [[ -f "${ROOT_DIR}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${ROOT_DIR}/.env"
  set +a
fi

API_HOSTNAME="${API_HOSTNAME:-api.financialcontrol.app.br}"
CERTBOT_EMAIL="${CERTBOT_EMAIL:?Set CERTBOT_EMAIL in the host .env}"

"${COMPOSE[@]}" up -d nginx

"${COMPOSE[@]}" --profile ops run --rm certbot certonly \
  --webroot \
  --webroot-path /var/www/certbot \
  --email "${CERTBOT_EMAIL}" \
  --agree-tos \
  --no-eff-email \
  --non-interactive \
  -d "${API_HOSTNAME}"

"${COMPOSE[@]}" up -d --no-deps --force-recreate nginx
