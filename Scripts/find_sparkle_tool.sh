#!/bin/zsh
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: Scripts/find_sparkle_tool.sh <generate_keys|generate_appcast|sign_update>" >&2
  exit 64
fi

TOOL_NAME="$1"
PROJECT_ROOT="${0:A:h:h}"

if [[ -n "${SPARKLE_BIN:-}" && -x "${SPARKLE_BIN}/${TOOL_NAME}" ]]; then
  echo "${SPARKLE_BIN}/${TOOL_NAME}"
  exit 0
fi

SEARCH_ROOTS=(
  "${PROJECT_ROOT}/DerivedData"
  "${HOME}/Library/Developer/Xcode/DerivedData"
)

for root in "${SEARCH_ROOTS[@]}"; do
  [[ -d "${root}" ]] || continue

  found="$(find "${root}" -type f -path "*/Sparkle/bin/${TOOL_NAME}" -perm -111 2>/dev/null | head -n 1)"
  if [[ -n "${found}" ]]; then
    echo "${found}"
    exit 0
  fi

  found="$(find "${root}" -type f -name "${TOOL_NAME}" -perm -111 2>/dev/null | head -n 1)"
  if [[ -n "${found}" ]]; then
    echo "${found}"
    exit 0
  fi
done

cat >&2 <<EOF
Sparkle tool not found: ${TOOL_NAME}

Open the project in Xcode and build once so Swift Package artifacts are resolved,
or pass SPARKLE_BIN=/path/to/Sparkle/bin when running this script.
EOF
exit 69
