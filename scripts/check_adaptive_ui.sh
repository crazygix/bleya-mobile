#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

FORBIDDEN_PATTERN='CupertinoPageRoute|showCupertinoDialog|showCupertinoModalPopup|CupertinoAlertDialog|CupertinoActionSheet|CupertinoDialogAction|CupertinoButton|CupertinoTextField|CupertinoActivityIndicator'

if rg -n "$FORBIDDEN_PATTERN" lib \
  --glob '!lib/platform/**' \
  --glob '!lib/platform/*.dart' >/tmp/adaptive_ui_violations.txt; then
  echo "Adaptive UI check failed: direct Cupertino usage found outside lib/platform/"
  cat /tmp/adaptive_ui_violations.txt
  exit 1
fi

echo "Adaptive UI check passed."
