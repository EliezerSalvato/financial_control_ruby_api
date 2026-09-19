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

BACKUP_BUCKET="${BACKUP_BUCKET:?Set BACKUP_BUCKET in the host .env (terraform output lightsail_bucket_name)}"
POSTGRES_USER="${POSTGRES_USER:?Set POSTGRES_USER in the host .env}"
POSTGRES_DB="${POSTGRES_DB:?Set POSTGRES_DB in the host .env}"
AWS_REGION="${AWS_REGION:-us-east-1}"
export PGPASSWORD="${POSTGRES_PASSWORD:-}"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
FILENAME="${POSTGRES_DB}-${STAMP}.sql.gz"
TMP_FILE="$(mktemp)"
trap 'rm -f "${TMP_FILE}"' EXIT

"${COMPOSE[@]}" exec -T db pg_dump -U "${POSTGRES_USER}" "${POSTGRES_DB}" | gzip -c > "${TMP_FILE}"

# Lightsail object storage: put-object + bucket-owner-full-control.
# Resource access on the instance supplies credentials; no access keys in .env.
aws s3api put-object \
  --bucket "${BACKUP_BUCKET}" \
  --key "postgres/${FILENAME}" \
  --body "${TMP_FILE}" \
  --acl bucket-owner-full-control \
  --region "${AWS_REGION}"

echo "Uploaded s3://${BACKUP_BUCKET}/postgres/${FILENAME}"
