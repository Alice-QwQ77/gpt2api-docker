#!/usr/bin/env bash
set -euo pipefail

MIGDIR="${MIGDIR:-/migrations}"
MYSQL_PWOPT=()
if [[ -n "${MYSQL_ROOT_PASSWORD:-}" ]]; then
  MYSQL_PWOPT=(-p"${MYSQL_ROOT_PASSWORD}")
fi

if [[ ! -d "$MIGDIR" ]]; then
  echo "[klein-init] no migrations dir at $MIGDIR, skip."
  exit 0
fi

shopt -s nullglob
files=( "$MIGDIR"/*.sql )
shopt -u nullglob

if [[ ${#files[@]} -eq 0 ]]; then
  echo "[klein-init] no .sql files in $MIGDIR, skip."
  exit 0
fi

IFS=$'\n' sorted=( $(printf '%s\n' "${files[@]}" | sort) )
unset IFS

for f in "${sorted[@]}"; do
  echo "[klein-init] applying $f ..."
  awk '
    /^[[:space:]]*--[[:space:]]*\+goose[[:space:]]+Up([[:space:]]|$)/ {flag=1; next}
    /^[[:space:]]*--[[:space:]]*\+goose[[:space:]]+Down([[:space:]]|$)/ {flag=0; next}
    /^[[:space:]]*--[[:space:]]*\+goose[[:space:]]+StatementBegin([[:space:]]|$)/ {next}
    /^[[:space:]]*--[[:space:]]*\+goose[[:space:]]+StatementEnd([[:space:]]|$)/ {next}
    flag {print}
  ' "$f" | mysql --default-character-set=utf8mb4 -uroot "${MYSQL_PWOPT[@]}" "${MYSQL_DATABASE}"
done

echo "[klein-init] all migrations applied."

