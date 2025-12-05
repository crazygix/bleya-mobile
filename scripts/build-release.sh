#!/bin/bash
# Build script for production releases
# Ensures FLUTTER_ENV=prod is always set for release builds

set -e

echo "Building Flutter app for production..."

# Build Android APK
echo "Building Android APK..."
flutter build apk --release --dart-define=FLUTTER_ENV=prod

# Build Android App Bundle
echo "Building Android App Bundle..."
flutter build appbundle --release --dart-define=FLUTTER_ENV=prod

# Build iOS (if on macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Building iOS..."
    flutter build ios --release --dart-define=FLUTTER_ENV=prod
fi

echo "✅ Production builds completed!"
echo "📦 APK: build/app/outputs/flutter-apk/app-release.apk"
echo "📦 AAB: build/app/outputs/bundle/release/app-release.aab"

