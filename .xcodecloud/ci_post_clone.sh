#!/bin/sh

set -eu

if [ -n "${CI_PRIMARY_REPOSITORY_PATH:-}" ]; then
  REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH}"
else
  REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fi

cd "${REPO_ROOT}"

FLUTTER_ROOT_DIR="${HOME}/flutter"

if command -v flutter >/dev/null 2>&1; then
  FLUTTER_BIN="$(command -v flutter)"
  FLUTTER_ROOT="$(cd "$(dirname "${FLUTTER_BIN}")/.." && pwd)"
elif [ -x "${FLUTTER_ROOT_DIR}/bin/flutter" ]; then
  FLUTTER_ROOT="${FLUTTER_ROOT_DIR}"
else
  git clone https://github.com/flutter/flutter.git --depth 1 --branch stable "${FLUTTER_ROOT_DIR}"
  FLUTTER_ROOT="${FLUTTER_ROOT_DIR}"
fi

export FLUTTER_ROOT
export PATH="${FLUTTER_ROOT}/bin:${PATH}"

flutter --version
flutter config --no-analytics
flutter precache --ios
flutter pub get
flutter build ios \
  --config-only \
  --release \
  --no-codesign \
  --dart-define-from-file=config/env/prod.example.json
