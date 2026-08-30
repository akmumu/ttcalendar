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

cleanup() {
  if [[ -n "${WORK_DIR}" && -d "${WORK_DIR}" ]]; then
    rm -rf "${WORK_DIR}"
  fi
}

trap cleanup EXIT

expand_entitlements() {
  local source="$1"
  local bundle_id="$2"
  local output="$3"

  /usr/bin/sed 's|$(PRODUCT_BUNDLE_IDENTIFIER)|'"${bundle_id}"'|g' "${source}" > "${output}"
}

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

adhoc_resign_for_free_distribution() {
  local source_app="$1"
  local signed_app="$2"
  local sign_entitlements="${PROJECT_ROOT}/ttcalendar/ttcalendar.entitlements"
  local widget_entitlements="${PROJECT_ROOT}/CalendarWidget/CalendarWidget.entitlements"
  local app_bundle_id
  local expanded_app_entitlements
  local widget_bundle_id
  local expanded_widget_entitlements

  echo "Preparing unsigned Developer ID-free package copy"
  ditto "${source_app}" "${signed_app}"

  find "${signed_app}" -name embedded.provisionprofile -delete

  app_bundle_id="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${signed_app}/Contents/Info.plist")"
  expanded_app_entitlements="${WORK_DIR}/ttcalendar.expanded.entitlements"
  expand_entitlements "${sign_entitlements}" "${app_bundle_id}" "${expanded_app_entitlements}"

  echo "Applying ad-hoc signatures for free distribution"
  codesign --force --sign - --preserve-metadata=identifier,entitlements,flags,runtime \
    "${signed_app}/Contents/Frameworks/Sparkle.framework"

  if [[ -d "${signed_app}/Contents/PlugIns/CalendarWidgetExtension.appex" ]]; then
    widget_bundle_id="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${signed_app}/Contents/PlugIns/CalendarWidgetExtension.appex/Contents/Info.plist")"
    expanded_widget_entitlements="${WORK_DIR}/CalendarWidget.expanded.entitlements"
    expand_entitlements "${widget_entitlements}" "${widget_bundle_id}" "${expanded_widget_entitlements}"

    codesign --force --sign - --entitlements "${expanded_widget_entitlements}" \
      "${signed_app}/Contents/PlugIns/CalendarWidgetExtension.appex"
  fi

  codesign --force --sign - --entitlements "${expanded_app_entitlements}" \
    "${signed_app}"

  if ! codesign --verify --deep --strict --verbose=2 "${signed_app}"; then
    cat >&2 <<EOF
Unable to create a self-consistent ad-hoc signed app for DMG packaging.
EOF
    exit 65
  fi

  PACKAGE_SOURCE_DIR="${signed_app:h}"
  PACKAGE_APP_PATH="${signed_app}"

  cat <<EOF
Created an ad-hoc signed DMG source for free distribution:
  ${PACKAGE_APP_PATH}

Users may still need to Control-click Open, or remove quarantine after download.
EOF
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

if [[ "${STRICT_RELEASE_CHECKS:-0}" == "1" ]]; then
  require_release_ready_app "${APP_PATH}"
else
  echo "Using free distribution mode. Set STRICT_RELEASE_CHECKS=1 for Developer ID notarized releases."
  WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ttcalendar-dmg.XXXXXX")"
  adhoc_resign_for_free_distribution "${APP_PATH}" "${WORK_DIR}/${APP_NAME}"
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
  --volname "${VOLUME_NAME}" \
  --window-size 500 340 \
  --icon-size 100 \
  --icon "${APP_NAME}" 140 140 \
  --app-drop-link 360 140 \
  "${DMG_PATH}" \
  "${PACKAGE_SOURCE_DIR}"

echo "Created ${DMG_PATH}"
