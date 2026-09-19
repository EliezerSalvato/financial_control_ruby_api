#!/bin/sh
set -eu

DOMAIN="${API_HOSTNAME:-api.financialcontrol.app.br}"
LIVE_DIR="/etc/letsencrypt/live/${DOMAIN}"
SSL_DIR="/etc/nginx/ssl"
TEMPLATE="/etc/nginx/templates/default.conf.template"
CONF="/etc/nginx/conf.d/default.conf"

mkdir -p "${SSL_DIR}" "$(dirname "${CONF}")"

if [ -f "${LIVE_DIR}/fullchain.pem" ] && [ -f "${LIVE_DIR}/privkey.pem" ]; then
  ln -sf "${LIVE_DIR}/fullchain.pem" "${SSL_DIR}/fullchain.pem"
  ln -sf "${LIVE_DIR}/privkey.pem" "${SSL_DIR}/privkey.pem"
else
  if ! command -v openssl >/dev/null 2>&1; then
    apk add --no-cache openssl
  fi
  openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
    -keyout "${SSL_DIR}/privkey.pem" \
    -out "${SSL_DIR}/fullchain.pem" \
    -subj "/CN=${DOMAIN}"
fi

sed "s|__API_HOSTNAME__|${DOMAIN}|g" "${TEMPLATE}" > "${CONF}"

exec nginx -g "daemon off;"
