# bleya

A Flutter chat application.

## Getting Started

This project is a starting point for a Flutter application that follows the
[simple app state management
tutorial](https://flutter.dev/to/state-management-sample).

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Building for Production

**⚠️ IMPORTANT: Always use `--dart-define=FLUTTER_ENV=prod` for release builds**

### Manual Build Commands

**Android:**
```bash
# APK
flutter build apk --release --dart-define=FLUTTER_ENV=prod

# App Bundle (for Play Store)
flutter build appbundle --release --dart-define=FLUTTER_ENV=prod
```

**iOS:**
```bash
flutter build ios --release --dart-define=FLUTTER_ENV=prod
```

### Why This Matters

Without `--dart-define=FLUTTER_ENV=prod`:
- ❌ App may point to `localhost` instead of production API
- ❌ Dev banner may show in production
- ❌ Debug logging may be enabled

## CI/CD

**Note:** Ensure your Railway CI/CD (or other CI/CD) includes `--dart-define=FLUTTER_ENV=prod` in build commands for production releases.

## Loading UI policy

Use the shared loading system across the app:

- `lib/widgets/app_spinner.dart` for action-level loading
- `lib/widgets/app_skeleton.dart` for content loading

Full policy and usage rules:

- `LOADING_UI_RULES.md`

## Assets

The `assets` directory houses images, fonts, and any other files you want to
include with your application.

The `assets/images` directory contains [resolution-aware
images](https://flutter.dev/to/resolution-aware-images).

## Localization

This project generates localized messages based on arb files found in
the `lib/src/localization` directory.

To support additional languages, please visit the tutorial on
[Internationalizing Flutter apps](https://flutter.dev/to/internationalization).
