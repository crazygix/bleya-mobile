#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PUBSPEC="pubspec.yaml"

if [[ -n "$(git status --porcelain -- "$PUBSPEC")" ]]; then
  echo "Aborting: $PUBSPEC has uncommitted changes before release." >&2
  exit 1
fi

BEFORE_VERSION="$(grep -E '^version:' "$PUBSPEC" | head -n1)"

bundle exec fastlane testing

AFTER_VERSION="$(grep -E '^version:' "$PUBSPEC" | head -n1)"

if [[ "$BEFORE_VERSION" == "$AFTER_VERSION" ]]; then
  echo "No version change detected in $PUBSPEC; nothing to commit."
  exit 0
fi

NEW_VERSION="${AFTER_VERSION#version:}"
NEW_VERSION="${NEW_VERSION// /}"

git add -- "$PUBSPEC"
git commit -m "chore(mobile): bump build to ${NEW_VERSION}"
git push

echo "Pushed bumped pubspec: ${NEW_VERSION}"
