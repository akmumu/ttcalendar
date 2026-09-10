#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"
WORKSPACE_ROOT="${PROJECT_ROOT:h}"

APP_NAME="${APP_NAME:-抬头日历.app}"
RELEASE_DIR="${RELEASE_DIR:-${WORKSPACE_ROOT}/release}"
DMG_PATH="${DMG_PATH:-${WORKSPACE_ROOT}/ttcalendar.dmg}"
VOLUME_NAME="${VOLUME_NAME:-抬头日历}"

APP_PATH="${RELEASE_DIR}/${APP_NAME}"
PACKAGE_SOURCE_DIR="${RELEASE_DIR}"
PACKAGE_APP_PATH="${APP_PATH}"
WORK_DIR=""
trap '[[ -z "$WORK_DIR" ]] || rm -rf "$WORK_DIR"' EXIT

require_release_ready_app() {
  local app_path="$1"

  echo "Verifying code signature"
  if ! codesign --verify --deep --strict --verbose=2 "${app_path}"; then
    cat >&2 <<EOF
The app is not release-signable as packaged.

Export it from Xcode with a Developer ID Application certificate, then run this
script against the exported app. Debug builds or CODE_SIGNING_ALLOWED=NO builds
are expected to fail here.
EOF
    exit 65
  fi

  if [[ "${SKIP_GATEKEEPER_CHECK:-0}" != "1" ]]; then
    echo "Assessing Gatekeeper policy"
    if ! spctl --assess --type execute --verbose=4 "${app_path}"; then
      cat >&2 <<EOF
Gatekeeper rejected this app.

For external distribution, notarize the exported app and staple the ticket before
creating the DMG. Set SKIP_GATEKEEPER_CHECK=1 only for private local testing.
EOF
      exit 65
    fi
  fi

  if [[ "${SKIP_STAPLER_CHECK:-0}" != "1" ]]; then
    echo "Validating notarization ticket"
    if ! xcrun stapler validate "${app_path}"; then
      cat >&2 <<EOF
No stapled notarization ticket was found.

Notarize and staple the exported app before packaging, or set
SKIP_STAPLER_CHECK=1 only if you intentionally rely on online notarization
lookup.
EOF
      exit 65
    fi
  fi
}

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

# Ad-hoc builds must use the extension's own container, never App Groups.
if [[ "${STRICT_RELEASE_CHECKS:-0}" == "1" ]]; then
  require_release_ready_app "${APP_PATH}"
else
  WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/ttcalendar-dmg.XXXXXX")
  PACKAGE_SOURCE_DIR="$WORK_DIR"
  PACKAGE_APP_PATH="$WORK_DIR/$APP_NAME"
  zsh "$SCRIPT_DIR/prepare_adhoc_app.sh" "$APP_PATH" "$PACKAGE_APP_PATH"
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

echo "Packaging ${PACKAGE_APP_PATH}"
echo "Writing ${DMG_PATH}"

create-dmg \
  --skip-jenkins \
  --volname "${VOLUME_NAME}" \
  --window-size 500 340 \
  --icon-size 100 \
  --icon "${APP_NAME}" 140 140 \
  --app-drop-link 360 140 \
  "${DMG_PATH}" \
  "${PACKAGE_SOURCE_DIR}"

echo "Created ${DMG_PATH}"
