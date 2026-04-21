#!/bin/sh

set -eu

if [ -z "${PROJECT_DIR:-}" ]; then
  echo "error: PROJECT_DIR is not set." >&2
  exit 1
fi

if [ -z "${GOOGLE_SERVICE_INFO_PLIST:-}" ]; then
  echo "error: GOOGLE_SERVICE_INFO_PLIST is not set for configuration ${CONFIGURATION:-unknown}." >&2
  exit 1
fi

SOURCE_PLIST="${PROJECT_DIR}/${GOOGLE_SERVICE_INFO_PLIST}"
DEST_PLIST="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/GoogleService-Info.plist"
INFO_PLIST="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
PLIST_BUDDY="/usr/libexec/PlistBuddy"

if [ ! -f "$SOURCE_PLIST" ]; then
  echo "error: Missing Firebase plist at $SOURCE_PLIST for configuration ${CONFIGURATION:-unknown}." >&2
  exit 1
fi

mkdir -p "$(dirname "$DEST_PLIST")"
cp "$SOURCE_PLIST" "$DEST_PLIST"

plist_value() {
  "$PLIST_BUDDY" -c "Print :$1" "$SOURCE_PLIST" 2>/dev/null || true
}

dart_define_value() {
  python3 - "$1" <<'PY'
import base64
import os
import sys

target = sys.argv[1]
raw = os.environ.get("DART_DEFINES", "")

for item in raw.split(","):
    if not item:
        continue
    padding = "=" * (-len(item) % 4)
    try:
        decoded = base64.urlsafe_b64decode(item + padding).decode("utf-8")
    except Exception:
        continue
    if "=" not in decoded:
        continue
    key, value = decoded.split("=", 1)
    if key == target:
        print(value)
        break
PY
}

CLIENT_ID="$(plist_value CLIENT_ID)"
if [ -z "$CLIENT_ID" ]; then
  CLIENT_ID="$(dart_define_value GOOGLE_IOS_CLIENT_ID)"
  if [ -n "$CLIENT_ID" ]; then
    echo "warning: CLIENT_ID missing from ${GOOGLE_SERVICE_INFO_PLIST}; falling back to GOOGLE_IOS_CLIENT_ID from DART_DEFINES." >&2
  fi
fi

SERVER_CLIENT_ID="$(plist_value SERVER_CLIENT_ID)"
if [ -z "$SERVER_CLIENT_ID" ]; then
  SERVER_CLIENT_ID="$(dart_define_value GOOGLE_SERVER_CLIENT_ID)"
fi

REVERSED_CLIENT_ID="$(plist_value REVERSED_CLIENT_ID)"
if [ -z "$REVERSED_CLIENT_ID" ] && [ -n "$CLIENT_ID" ]; then
  case "$CLIENT_ID" in
    *.apps.googleusercontent.com)
      suffix="${CLIENT_ID%.apps.googleusercontent.com}"
      REVERSED_CLIENT_ID="com.googleusercontent.apps.${suffix}"
      echo "warning: REVERSED_CLIENT_ID missing from ${GOOGLE_SERVICE_INFO_PLIST}; derived it from CLIENT_ID." >&2
      ;;
  esac
fi

if [ -z "$CLIENT_ID" ] || [ -z "$REVERSED_CLIENT_ID" ]; then
  echo "error: Missing iOS Google Sign-In identifiers for ${CONFIGURATION:-unknown}." >&2
  echo "error: Ensure ${GOOGLE_SERVICE_INFO_PLIST} includes CLIENT_ID/REVERSED_CLIENT_ID, or provide GOOGLE_IOS_CLIENT_ID in the dart defines file for this flavor." >&2
  exit 1
fi

"$PLIST_BUDDY" -c "Delete :GIDClientID" "$INFO_PLIST" 2>/dev/null || true
"$PLIST_BUDDY" -c "Add :GIDClientID string $CLIENT_ID" "$INFO_PLIST"

"$PLIST_BUDDY" -c "Delete :GIDServerClientID" "$INFO_PLIST" 2>/dev/null || true
if [ -n "$SERVER_CLIENT_ID" ]; then
  "$PLIST_BUDDY" -c "Add :GIDServerClientID string $SERVER_CLIENT_ID" "$INFO_PLIST"
fi

"$PLIST_BUDDY" -c "Delete :CFBundleURLTypes" "$INFO_PLIST" 2>/dev/null || true
"$PLIST_BUDDY" -c "Add :CFBundleURLTypes array" "$INFO_PLIST"
"$PLIST_BUDDY" -c "Add :CFBundleURLTypes:0 dict" "$INFO_PLIST"
"$PLIST_BUDDY" -c "Add :CFBundleURLTypes:0:CFBundleTypeRole string Editor" "$INFO_PLIST"
"$PLIST_BUDDY" -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "$INFO_PLIST"
"$PLIST_BUDDY" -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string $REVERSED_CLIENT_ID" "$INFO_PLIST"
