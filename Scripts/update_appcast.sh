#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"
WORKSPACE_ROOT="${PROJECT_ROOT:h}"
APPCAST_DIR="${APPCAST_DIR:-${PROJECT_ROOT}/docs}"
DMG_PATH="${DMG_PATH:-${WORKSPACE_ROOT}/ttcalendar.dmg}"
KEY_ACCOUNT="${SPARKLE_KEY_ACCOUNT:-ed25519}"
MAXIMUM_VERSIONS="${MAXIMUM_VERSIONS:-1}"
MAXIMUM_DELTAS="${MAXIMUM_DELTAS:-0}"

GENERATE_APPCAST="$("${SCRIPT_DIR}/find_sparkle_tool.sh" generate_appcast)"

if [[ ! -f "${DMG_PATH}" ]]; then
  echo "DMG not found: ${DMG_PATH}" >&2
  echo "Run Scripts/package_dmg.sh first, or pass DMG_PATH=/path/to/update.dmg." >&2
  exit 66
fi

marketing_version="$(awk -F ' = ' '/MARKETING_VERSION =/ { gsub(/;/, "", $2); print $2; exit }' "${PROJECT_ROOT}/ttcalendar.xcodeproj/project.pbxproj")"
if [[ -z "${marketing_version}" ]]; then
  echo "Could not read MARKETING_VERSION from project.pbxproj" >&2
  exit 65
fi

RELEASE_TAG="${RELEASE_TAG:-${marketing_version}}"
DOWNLOAD_URL_PREFIX="${DOWNLOAD_URL_PREFIX:-https://github.com/akmumu/ttcalendar/releases/download/${RELEASE_TAG}/}"
if [[ "${DOWNLOAD_URL_PREFIX}" != */ ]]; then
  DOWNLOAD_URL_PREFIX="${DOWNLOAD_URL_PREFIX}/"
fi

mkdir -p "${APPCAST_DIR}"
cp "${DMG_PATH}" "${APPCAST_DIR}/"

dmg_name="${DMG_PATH:t}"
notes_source="${RELEASE_NOTES:-${PROJECT_ROOT}/release-notes/${marketing_version}.html}"
if [[ -f "${notes_source}" ]]; then
  cp "${notes_source}" "${APPCAST_DIR}/${dmg_name:r}.html"
else
  echo "No release notes found at ${notes_source}; continuing without notes."
fi

echo "Generating Sparkle appcast in ${APPCAST_DIR}"
echo "Download URL prefix: ${DOWNLOAD_URL_PREFIX}"
echo "Keychain account: ${KEY_ACCOUNT}"

"${GENERATE_APPCAST}" \
  --account "${KEY_ACCOUNT}" \
  --download-url-prefix "${DOWNLOAD_URL_PREFIX}" \
  --maximum-versions "${MAXIMUM_VERSIONS}" \
  --maximum-deltas "${MAXIMUM_DELTAS}" \
  "${APPCAST_DIR}"

echo
echo "Updated ${APPCAST_DIR}/appcast.xml"
echo "Commit appcast.xml and release notes, but do not commit the copied dmg."
