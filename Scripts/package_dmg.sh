#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"
WORKSPACE_ROOT="${PROJECT_ROOT:h}"

APP_NAME="${APP_NAME:-抬头日历.app}"
RELEASE_DIR="${RELEASE_DIR:-${WORKSPACE_ROOT}/release}"
DMG_PATH="${DMG_PATH:-${WORKSPACE_ROOT}/抬头日历-Mac版.dmg}"
VOLUME_NAME="${VOLUME_NAME:-抬头日历}"

APP_PATH="${RELEASE_DIR}/${APP_NAME}"

if ! command -v create-dmg >/dev/null 2>&1; then
  echo "create-dmg not found. Install it first, for example: brew install create-dmg" >&2
  exit 69
fi

if [[ ! -d "${APP_PATH}" ]]; then
  cat >&2 <<EOF
Exported app not found:
  ${APP_PATH}

Archive in Xcode, export the app, and put ${APP_NAME} in:
  ${RELEASE_DIR}

Override with RELEASE_DIR=/path/to/release if needed.
EOF
  exit 66
fi

if [[ -e "${DMG_PATH}" ]]; then
  if [[ "${OVERWRITE_DMG:-0}" == "1" ]]; then
    rm -f "${DMG_PATH}"
  else
    cat >&2 <<EOF
DMG already exists:
  ${DMG_PATH}

Set OVERWRITE_DMG=1 to replace it, or pass DMG_PATH=/path/to/new.dmg.
EOF
    exit 73
  fi
fi

echo "Packaging ${APP_PATH}"
echo "Writing ${DMG_PATH}"

create-dmg \
  --volname "${VOLUME_NAME}" \
  --window-size 500 340 \
  --icon-size 100 \
  --icon "${APP_NAME}" 140 140 \
  --app-drop-link 360 140 \
  "${DMG_PATH}" \
  "${RELEASE_DIR}"

echo "Created ${DMG_PATH}"
