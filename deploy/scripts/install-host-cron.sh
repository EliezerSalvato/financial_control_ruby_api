#!/bin/bash
set -euo pipefail

ROOT_DIR="/opt/financial-control"
DUMP_JOB="/bin/bash ${ROOT_DIR}/deploy/scripts/pg-dump-to-bucket.sh"
RENEW_JOB="/bin/bash ${ROOT_DIR}/deploy/scripts/renew-cert.sh"
MARKER="financial-control-ops"
LOG_DIR="${ROOT_DIR}/log"
CRON_PATH="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
CRON_SHELL="SHELL=/bin/bash"

mkdir -p "${LOG_DIR}"

cron_user=""
if [[ "$(id -u)" -eq 0 ]] && id ubuntu >/dev/null 2>&1; then
  cron_user="ubuntu"
  chown ubuntu:ubuntu "${LOG_DIR}"
fi

read_crontab() {
  if [[ -n "${cron_user}" ]]; then
    crontab -u "${cron_user}" -l 2>/dev/null || true
  else
    crontab -l 2>/dev/null || true
  fi
}

write_crontab() {
  if [[ -n "${cron_user}" ]]; then
    crontab -u "${cron_user}" -
  else
    crontab -
  fi
}

filtered="$(
  read_crontab \
    | grep -v -F "deploy/scripts/pg-dump-to-bucket.sh" \
    | grep -v -F "deploy/scripts/renew-cert.sh" \
    | grep -v -F -- "--profile ops run --rm certbot" \
    | grep -v -E '^PATH=' \
    | grep -v -E '^SHELL=' \
    | grep -v "${MARKER}" \
    || true
)"

{
  echo "${CRON_PATH}"
  echo "${CRON_SHELL}"
  if [[ -n "${filtered}" ]]; then
    printf '%s\n' "${filtered}"
  fi
  echo "# ${MARKER} postgres dump 04:00 UTC"
  echo "0 4 * * * ${DUMP_JOB} >> ${LOG_DIR}/backup.log 2>&1"
  echo "# ${MARKER} certbot renew"
  echo "15 3,15 * * * ${RENEW_JOB} >> ${LOG_DIR}/cert-renew.log 2>&1"
} | write_crontab
