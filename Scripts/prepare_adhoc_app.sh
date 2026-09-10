#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
SOURCE="${1:?Pass the built app path}"
OUTPUT="${2:?Pass a new output app path}"
WIDGET="Contents/PlugIns/CalendarWidgetExtension.appex"

if [[ -e "$OUTPUT" ]]; then
  echo "Output already exists: $OUTPUT" >&2
  exit 73
fi
for bundle in "$SOURCE" "$SOURCE/$WIDGET"; do
  transport=$(/usr/libexec/PlistBuddy -c 'Print :WidgetDataTransport' "$bundle/Contents/Info.plist" 2>/dev/null || true)
  if [[ "$transport" != widgetContainer-v1 ]]; then
    echo "Refusing ad-hoc signing: $bundle does not use widgetContainer-v1." >&2
    exit 65
  fi
done

ditto "$SOURCE" "$OUTPUT"
rm -f "$OUTPUT/Contents/embedded.provisionprofile" "$OUTPUT/$WIDGET/Contents/embedded.provisionprofile"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/ttcalendar-sign.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
bundle_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$OUTPUT/Contents/Info.plist")
sed 's|$(PRODUCT_BUNDLE_IDENTIFIER)|'"$bundle_id"'|g' "$ROOT/ttcalendar/ttcalendar.entitlements" > "$WORK/app.entitlements"

codesign --force --sign - --preserve-metadata=identifier,entitlements,flags,runtime "$OUTPUT/Contents/Frameworks/Sparkle.framework"
codesign --force --sign - --entitlements "$ROOT/CalendarWidget/CalendarWidget.entitlements" "$OUTPUT/$WIDGET"
codesign --force --sign - --entitlements "$WORK/app.entitlements" "$OUTPUT"
codesign --verify --deep --strict "$OUTPUT"
echo "Prepared ad-hoc app: $OUTPUT"
