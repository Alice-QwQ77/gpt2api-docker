#!/usr/bin/env sh
set -eu

BACKEND_IMAGE="${BACKEND_IMAGE:-}"
ADMIN_WEB_IMAGE="${ADMIN_WEB_IMAGE:-}"
USER_WEB_IMAGE="${USER_WEB_IMAGE:-}"
BACKEND_PACKAGE_NAME="${BACKEND_PACKAGE_NAME:-gpt2api}"
ADMIN_WEB_PACKAGE_NAME="${ADMIN_WEB_PACKAGE_NAME:-gpt2api-admin-web}"
USER_WEB_PACKAGE_NAME="${USER_WEB_PACKAGE_NAME:-gpt2api-user-web}"
DEFAULT_OWNER="${DEFAULT_OWNER:-alice-qwq77}"
ENV_PATH="${ENV_PATH:-.env}"
FORCE="${FORCE:-0}"

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
TEMPLATE_PATH="$SCRIPT_DIR/.env.example"
OUTPUT_PATH="$SCRIPT_DIR/$ENV_PATH"

resolve_ghcr_image() {
  remote_url="$1"
  case "$remote_url" in
    https://github.com/*)
      path="${remote_url#https://github.com/}"
      ;;
    git@github.com:*)
      path="${remote_url#git@github.com:}"
      ;;
    ssh://git@github.com/*)
      path="${remote_url#ssh://git@github.com/}"
      ;;
    *)
      echo "unable to derive ghcr image from remote: $remote_url" >&2
      return 1
      ;;
  esac

  path="${path%/}"
  path="${path%.git}"
  owner=$(printf '%s' "$path" | cut -d/ -f1)
  printf 'ghcr.io/%s/%s:latest\n' "$owner" "$PACKAGE_NAME" | tr '[:upper:]' '[:lower:]'
}

if [ ! -f "$TEMPLATE_PATH" ]; then
  echo "template not found: $TEMPLATE_PATH" >&2
  exit 1
fi

if [ -f "$OUTPUT_PATH" ] && [ "$FORCE" != "1" ]; then
  echo "$OUTPUT_PATH already exists. Set FORCE=1 to overwrite." >&2
  exit 1
fi

if [ -z "$BACKEND_IMAGE" ] || [ -z "$ADMIN_WEB_IMAGE" ] || [ -z "$USER_WEB_IMAGE" ]; then
  remote=$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null || true)
  if [ -n "$remote" ]; then
    [ -n "$BACKEND_IMAGE" ] || BACKEND_IMAGE=$(PACKAGE_NAME="$BACKEND_PACKAGE_NAME" resolve_ghcr_image "$remote")
    [ -n "$ADMIN_WEB_IMAGE" ] || ADMIN_WEB_IMAGE=$(PACKAGE_NAME="$ADMIN_WEB_PACKAGE_NAME" resolve_ghcr_image "$remote")
    [ -n "$USER_WEB_IMAGE" ] || USER_WEB_IMAGE=$(PACKAGE_NAME="$USER_WEB_PACKAGE_NAME" resolve_ghcr_image "$remote")
  else
    [ -n "$BACKEND_IMAGE" ] || BACKEND_IMAGE=$(printf 'ghcr.io/%s/%s:latest\n' "$DEFAULT_OWNER" "$BACKEND_PACKAGE_NAME" | tr '[:upper:]' '[:lower:]')
    [ -n "$ADMIN_WEB_IMAGE" ] || ADMIN_WEB_IMAGE=$(printf 'ghcr.io/%s/%s:latest\n' "$DEFAULT_OWNER" "$ADMIN_WEB_PACKAGE_NAME" | tr '[:upper:]' '[:lower:]')
    [ -n "$USER_WEB_IMAGE" ] || USER_WEB_IMAGE=$(printf 'ghcr.io/%s/%s:latest\n' "$DEFAULT_OWNER" "$USER_WEB_PACKAGE_NAME" | tr '[:upper:]' '[:lower:]')
  fi
fi

sed \
  -e "s#^KLEIN_BACKEND_IMAGE=.*#KLEIN_BACKEND_IMAGE=$BACKEND_IMAGE#" \
  -e "s#^KLEIN_ADMIN_WEB_IMAGE=.*#KLEIN_ADMIN_WEB_IMAGE=$ADMIN_WEB_IMAGE#" \
  -e "s#^KLEIN_USER_WEB_IMAGE=.*#KLEIN_USER_WEB_IMAGE=$USER_WEB_IMAGE#" \
  "$TEMPLATE_PATH" > "$OUTPUT_PATH"

echo "[init-env] wrote $OUTPUT_PATH"
echo "[init-env] KLEIN_BACKEND_IMAGE=$BACKEND_IMAGE"
echo "[init-env] KLEIN_ADMIN_WEB_IMAGE=$ADMIN_WEB_IMAGE"
echo "[init-env] KLEIN_USER_WEB_IMAGE=$USER_WEB_IMAGE"
