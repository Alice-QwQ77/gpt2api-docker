#!/usr/bin/env bash
set -euo pipefail

MYSQL_HOST=${MYSQL_HOST:-mysql}
MYSQL_PORT=${MYSQL_PORT:-3306}
MYSQL_USER=${MYSQL_USER:-gpt2api}
MYSQL_PASSWORD=${MYSQL_PASSWORD:-gpt2api}
MYSQL_DATABASE=${MYSQL_DATABASE:-gpt2api}

log() { echo "[entrypoint] $*"; }

prepare_config() {
  if [[ -f /app/configs/config.yaml ]]; then
    return 0
  fi
  if [[ -f /app/configs/config.example.yaml ]]; then
    cp /app/configs/config.example.yaml /app/configs/config.yaml
    log "config.yaml missing, copied from config.example.yaml"
  fi
}

wait_mysql() {
  log "waiting for mysql ${MYSQL_HOST}:${MYSQL_PORT}..."
  local i=0
  while (( i < 60 )); do
    if MYSQL_PWD="${MYSQL_PASSWORD}" mysqladmin ping \
      -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" -u "${MYSQL_USER}" --silent 2>/dev/null; then
      log "mysql is up."
      return 0
    fi
    sleep 1
    i=$((i+1))
  done
  log "mysql did not become ready in 60s, continuing anyway."
  return 1
}

run_migrate() {
  if [[ "${SKIP_MIGRATE:-0}" == "1" ]]; then
    log "SKIP_MIGRATE=1, skipping migrations"
    return 0
  fi
  local dsn="${MYSQL_USER}:${MYSQL_PASSWORD}@tcp(${MYSQL_HOST}:${MYSQL_PORT})/${MYSQL_DATABASE}?parseTime=true&multiStatements=true&charset=utf8mb4,utf8"
  log "running goose migrations..."
  goose -dir /app/sql/migrations mysql "${dsn}" up
  log "migrations done."
}

prepare_config
wait_mysql || true
run_migrate || { log "migration failed"; exit 1; }

log "starting: $*"
exec "$@"

