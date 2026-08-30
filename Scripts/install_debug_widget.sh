#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"

PROJECT_PATH="${PROJECT_ROOT}/ttcalendar.xcodeproj"
SCHEME="${SCHEME:-ttcalendar}"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA="${DERIVED_DATA:-/private/tmp/ttcalendar-widget-dev}"
DESTINATION="${DESTINATION:-platform=macOS,arch=$(uname -m)}"
APP_NAME="抬头日历.app"
INSTALL_APP="${INSTALL_APP:-/Applications/${APP_NAME}}"
WIDGET_EXTENSION_ID="akmumu.ttcalendar.CalendarWidget"
INSTALLED_WIDGET_EXECUTABLE="${INSTALL_APP}/Contents/PlugIns/CalendarWidgetExtension.appex/Contents/MacOS/CalendarWidgetExtension"

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"

stop_installed_widget_extension() {
  local pids
  pids="$(pgrep -f "${INSTALLED_WIDGET_EXECUTABLE}" 2>/dev/null || true)"

  if [[ -z "${pids}" ]]; then
    return
  fi

  echo "Stopping existing ${WIDGET_EXTENSION_ID} extension process..."
  while IFS= read -r pid; do
    [[ -z "${pid}" ]] && continue
    kill "${pid}" 2>/dev/null || true
  done <<< "${pids}"

  sleep 1

  pids="$(pgrep -f "${INSTALLED_WIDGET_EXECUTABLE}" 2>/dev/null || true)"
  if [[ -n "${pids}" ]]; then
    echo "Force-stopping stubborn ${WIDGET_EXTENSION_ID} extension process..."
    while IFS= read -r pid; do
      [[ -z "${pid}" ]] && continue
      kill -9 "${pid}" 2>/dev/null || true
    done <<< "${pids}"
  fi
}

# Building registers the .appex inside the build folder with LaunchServices, so
# every run otherwise leaves another copy of ${WIDGET_EXTENSION_ID} behind. Too
# many copies of the same widget bundle id make chronod pick the wrong one and
# the desktop widget gets stuck on its placeholder. Keep only ${INSTALL_APP}.
cleanup_build_registrations() {
  echo "Pruning duplicate widget registrations (keeping ${INSTALL_APP})..."
  local dump p
  dump="$("${LSREGISTER}" -dump 2>/dev/null || true)"
  printf '%s\n' "${dump}" \
    | grep -iE "path:.*${APP_NAME}(/| \(0x)" \
    | sed -E 's/.*path:[[:space:]]*//; s/ \(0x.*//' \
    | sort -u \
    | while IFS= read -r p; do
        case "${p}" in
          "${INSTALL_APP}"|"${INSTALL_APP}"/*) ;;            # keep the installed app
          *) "${LSREGISTER}" -u "${p}" >/dev/null 2>&1 || true ;;
        esac
      done || true

  # Xcode builds made outside this script can remain registered and appear as
  # duplicate apps in system search. Unregister them without deleting Xcode's
  # build products or indexes.
  local default_derived_data="${HOME}/Library/Developer/Xcode/DerivedData"
  if [[ -d "${default_derived_data}" ]]; then
    find "${default_derived_data}" -type d -name "${APP_NAME}" -prune -print0 2>/dev/null \
      | while IFS= read -r -d '' p; do
          [[ "${p}" == "${INSTALL_APP}" ]] && continue
          "${LSREGISTER}" -u "${p}" >/dev/null 2>&1 || true
        done
  fi

  # Drop the throwaway build tree so its bundles cannot be re-registered later.
  if [[ "${DERIVED_DATA}" == /private/tmp/* && -d "${DERIVED_DATA}" ]]; then
    rm -rf "${DERIVED_DATA}"
  fi
}

echo "Building ${SCHEME} (${CONFIGURATION}) for WidgetKit development..."
xcodebuild \
  -project "${PROJECT_PATH}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -destination "${DESTINATION}" \
  -derivedDataPath "${DERIVED_DATA}" \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  ENABLE_DEBUG_DYLIB=NO \
  ENABLE_PREVIEWS=NO \
  clean build

BUILT_APP="${DERIVED_DATA}/Build/Products/${CONFIGURATION}/${APP_NAME}"
BUILT_EXTENSION="${BUILT_APP}/Contents/PlugIns/CalendarWidgetExtension.appex"

if [[ ! -d "${BUILT_APP}" ]]; then
  echo "Built app not found: ${BUILT_APP}" >&2
  exit 1
fi

echo "Verifying code signatures..."
codesign --verify --strict --verbose=2 "${BUILT_APP}"
codesign --verify --strict --verbose=2 "${BUILT_EXTENSION}"

echo "Installing to ${INSTALL_APP}..."
stop_installed_widget_extension

if [[ -e "${INSTALL_APP}" ]]; then
  rm -rf "${INSTALL_APP}"
fi
ditto "${BUILT_APP}" "${INSTALL_APP}"

echo "Registering app and widget extension..."
"${LSREGISTER}" -f -R -trusted "${INSTALL_APP}"
xcrun pluginkit -a "${INSTALL_APP}/Contents/PlugIns/CalendarWidgetExtension.appex"
xcrun pluginkit -e use -i "${WIDGET_EXTENSION_ID}"

cleanup_build_registrations

echo "Launching installed app..."
open "${INSTALL_APP}"

if [[ "${RESTART_WIDGET_HOSTS:-0}" == "1" ]]; then
  echo "Restarting WidgetKit host processes..."
  killall chronod 2>/dev/null || true
  killall NotificationCenter 2>/dev/null || true
fi

echo "Registered WidgetKit extensions:"
xcrun pluginkit -m -p com.apple.widgetkit-extension | grep -E "(${WIDGET_EXTENSION_ID}|com.apple.iCal.CalendarWidgetExtension|com.microsoft.Outlook.CalendarWidget)" || true

echo "Done. If the desktop widget still shows stale content, rerun with RESTART_WIDGET_HOSTS=1."
