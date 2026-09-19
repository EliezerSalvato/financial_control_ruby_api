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

"${COMPOSE[@]}" --profile ops run --rm certbot renew --non-interactive
"${COMPOSE[@]}" exec -T nginx nginx -s reload
