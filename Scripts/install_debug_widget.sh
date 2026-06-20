#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIR:h}"

PROJECT_PATH="${PROJECT_ROOT}/ttcalendar.xcodeproj"
SCHEME="${SCHEME:-ttcalendar}"
CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA="${DERIVED_DATA:-/private/tmp/ttcalendar-widget-dev}"
APP_NAME="抬头日历.app"
INSTALL_APP="${INSTALL_APP:-/Applications/${APP_NAME}}"
WIDGET_EXTENSION_ID="akmumu.ttcalendar.CalendarWidget"

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"

echo "Building ${SCHEME} (${CONFIGURATION}) for WidgetKit development..."
xcodebuild \
  -project "${PROJECT_PATH}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "${DERIVED_DATA}" \
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
if [[ -e "${INSTALL_APP}" ]]; then
  rm -rf "${INSTALL_APP}"
fi
ditto "${BUILT_APP}" "${INSTALL_APP}"

echo "Registering app and widget extension..."
"${LSREGISTER}" -f -R -trusted "${INSTALL_APP}"
xcrun pluginkit -a "${INSTALL_APP}/Contents/PlugIns/CalendarWidgetExtension.appex"
xcrun pluginkit -e use -i "${WIDGET_EXTENSION_ID}"

echo "Launching installed app..."
open "${INSTALL_APP}"

echo "Registered WidgetKit extensions:"
xcrun pluginkit -m -p com.apple.widgetkit-extension | grep -E "(${WIDGET_EXTENSION_ID}|com.apple.iCal.CalendarWidgetExtension|com.microsoft.Outlook.CalendarWidget)" || true

echo "Done. Reopen the widget picker and search for 抬头日历."
