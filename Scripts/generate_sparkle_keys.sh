#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"
INFO_PLIST="${INFO_PLIST:-${PROJECT_ROOT}/ttcalendar/Info.plist}"
KEY_ACCOUNT="${SPARKLE_KEY_ACCOUNT:-akmumu.ttcalendar}"
GENERATE_KEYS="$("${SCRIPT_DIR}/find_sparkle_tool.sh" generate_keys)"

echo "Generating or reusing Sparkle EdDSA key in Keychain account: ${KEY_ACCOUNT}"
output="$("${GENERATE_KEYS}" --account "${KEY_ACCOUNT}")"
echo "${output}"

public_key="$(echo "${output}" | grep -Eo '[A-Za-z0-9+/]{43}=' | tail -n 1)"
if [[ -z "${public_key}" ]]; then
  echo "Could not parse SUPublicEDKey from generate_keys output." >&2
  exit 1
fi

if [[ ! -f "${INFO_PLIST}" ]]; then
  echo "Info.plist not found: ${INFO_PLIST}" >&2
  exit 1
fi

/usr/libexec/PlistBuddy -c "Set :SUPublicEDKey ${public_key}" "${INFO_PLIST}" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string ${public_key}" "${INFO_PLIST}"

echo
echo "Updated ${INFO_PLIST}"
echo "SUPublicEDKey=${public_key}"
echo
echo "Keep the private key in Keychain. Do not export or commit it unless you are deliberately moving it to another secure machine."
