#!/bin/sh
set -eu

cmd="${1:-api}"
if [ "$#" -gt 0 ]; then
  shift
fi

ensure_runtime_dirs() {
  mkdir -p /app/logs /app/storage/public
  chown -R nginx:nginx /app/logs /app/storage 2>/dev/null || true
}

case "$cmd" in
  api|admin|openai|worker)
    ensure_runtime_dirs
    exec su-exec nginx "/app/$cmd" "$@"
    ;;
  /app/api|/app/admin|/app/openai|/app/worker|/app/goose)
    ensure_runtime_dirs
    exec su-exec nginx "$cmd" "$@"
    ;;
  goose|migrate)
    ensure_runtime_dirs
    exec su-exec nginx /app/goose "$@"
    ;;
  user-web)
    cp /app/nginx/user-web.conf /etc/nginx/conf.d/default.conf
    exec nginx -g "daemon off;"
    ;;
  admin-web)
    cp /app/nginx/admin-web.conf /etc/nginx/conf.d/default.conf
    exec nginx -g "daemon off;"
    ;;
  nginx)
    exec nginx "$@"
    ;;
  *)
    exec "$cmd" "$@"
    ;;
esac
