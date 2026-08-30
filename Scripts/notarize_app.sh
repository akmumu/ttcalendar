#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"
WORKSPACE_ROOT="${PROJECT_ROOT:h}"

APP_NAME="${APP_NAME:-抬头日历.app}"
RELEASE_DIR="${RELEASE_DIR:-${WORKSPACE_ROOT}/release}"
APP_PATH="${RELEASE_DIR}/${APP_NAME}"
NOTARY_PROFILE="${NOTARY_PROFILE:-ttcalendar-notary}"
ARCHIVE_PATH="${ARCHIVE_PATH:-${WORKSPACE_ROOT}/ttcalendar-notary.zip}"

if [[ ! -d "${APP_PATH}" ]]; then
  cat >&2 <<EOF
Exported app not found:
  ${APP_PATH}

Archive in Xcode, export with Developer ID Application signing, and put
${APP_NAME} in:
  ${RELEASE_DIR}
EOF
  exit 66
fi

echo "Verifying Developer ID signature"
if ! codesign --verify --deep --strict --verbose=4 "${APP_PATH}"; then
  cat >&2 <<EOF
Code signature verification failed.

Re-export the archive with a trusted Developer ID Application certificate before
notarization. A local Gatekeeper override is not enough for external users.
EOF
  exit 65
fi

echo "Creating notarization archive: ${ARCHIVE_PATH}"
rm -f "${ARCHIVE_PATH}"
/usr/bin/ditto -c -k --keepParent "${APP_PATH}" "${ARCHIVE_PATH}"

cat <<EOF
Submitting to Apple notarization service with keychain profile:
  ${NOTARY_PROFILE}

If this profile does not exist yet, create it once with:
  xcrun notarytool store-credentials ${NOTARY_PROFILE} --apple-id APPLE_ID --team-id TEAM_ID

Use an app-specific password when prompted.
EOF

xcrun notarytool submit "${ARCHIVE_PATH}" \
  --keychain-profile "${NOTARY_PROFILE}" \
  --wait

echo "Stapling notarization ticket"
xcrun stapler staple "${APP_PATH}"

echo "Validating stapled ticket"
xcrun stapler validate "${APP_PATH}"

echo "Assessing Gatekeeper policy"
spctl --assess --type execute --verbose=4 "${APP_PATH}"

echo "Notarization complete: ${APP_PATH}"
