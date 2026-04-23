# Bleya Mobile

Flutter client for Bleya.

This app connects to the Bleya backend in `../backend` and currently covers:

- Google, Apple, and passkey sign-in
- Username onboarding
- Public city-based chat rooms
- Direct messages, blocking, and chat deletion
- Thread replies and realtime socket updates
- Activity/notification inbox
- Profile editing and blocked-users management

## Requirements

- Flutter stable
- Dart 3.6+
- JDK `17` for Android builds

Check your local toolchain:

```bash
flutter --version
```

## Quick Start

1. Copy env templates:

```bash
cp config/env/dev.example.json config/env/dev.local.json
cp config/env/prod.example.json config/env/prod.local.json
```

2. Set `API_BASE_URL` in `config/env/dev.local.json`:

- Android emulator: `http://10.0.2.2:8080/v1`
- iOS simulator: `http://127.0.0.1:8080/v1`
- Physical device: `http://<LAN_IP_OF_MAC>:8080/v1`

3. Start the backend from `../backend`:

```bash
npm run build && npm start
```

4. Verify the backend is reachable:

```bash
curl http://127.0.0.1:8080/health
```

5. Run the app:

```bash
flutter run --flavor dev --dart-define-from-file=config/env/dev.local.json
```

## Run from Cursor (Multi-root Workspace)

1) Open [bleya.code-workspace](/Users/ivan.kokanovic/Development/bleya/mobile/bleya.code-workspace) in Cursor.
2) Run task `Backend: Start Dev Server`.
3) Start your Android emulator or iOS simulator/device.
4) Run command `Flutter: Select Device` and pick Android or iOS.
5) In Run and Debug, launch `Mobile dev`.

Notes:
- Workspace launch config is the single source of truth for Flutter runs.
- `Mobile dev` uses flavor `dev` and reads `config/env/dev.local.json`.
- `Mobile prod`/`Mobile release` use flavor `prod` and read `config/env/prod.local.json`.
- If your LAN IP changes, update `API_BASE_URL` in `config/env/dev.local.json` only.
- Available schemes: `Backend dev`, `Mobile dev`, `Mobile prod`, `Mobile release`.

## Configuration Files

Committed templates:

- `config/env/dev.example.json`
- `config/env/prod.example.json`

Local-only files (gitignored):

- `config/env/dev.local.json`
- `config/env/prod.local.json`

Both files use the same schema:

- `FLUTTER_ENV`
- `API_BASE_URL`
- `GOOGLE_SERVER_CLIENT_ID`
- `GOOGLE_IOS_CLIENT_ID`
- `APPLE_SERVICE_ID`
- `APPLE_REDIRECT_URI`
- `PASSKEY_DOMAIN`

`GOOGLE_IOS_CLIENT_ID` is now only a fallback for iOS builds when the selected
`GoogleService-Info.plist` does not include `CLIENT_ID`. The preferred source
of truth is the flavor-specific iOS Firebase plist. Once `dev` and `prod`
bundle IDs diverge, the iOS client IDs will usually diverge too.

## Native Environment Split

This project now uses native `dev` and `prod` app variants in addition to the
existing Dart define files.

Android:

- `dev` flavor -> application ID `com.bleyachat.dev`
- `prod` flavor -> application ID `com.bleyachat`
- Firebase files:
  - `android/app/src/dev/google-services.json`
  - `android/app/src/prod/google-services.json`

iOS:

- `dev` scheme/config -> bundle ID `com.bleyachat.dev`
- `prod` scheme/config -> bundle ID `com.bleyachat`
- Firebase files:
  - `ios/Runner/Firebase/Dev/GoogleService-Info.plist`
  - `ios/Runner/Firebase/Prod/GoogleService-Info.plist`

For iOS Google sign-in, each flavor also needs valid Google Sign-In metadata.
The build now injects `GIDClientID` and the callback URL scheme from the
selected `GoogleService-Info.plist`. If a plist is missing `CLIENT_ID`, the
build falls back to `GOOGLE_IOS_CLIENT_ID` from the dart defines for that
flavor.

## Push Notifications

Push delivery now uses Firebase Cloud Messaging on mobile and the existing
backend push endpoints/socket presence flow.

App behavior:

- FCM is initialized at app startup.
- After login, the app requests notification permission, fetches the FCM token,
  and registers it with the backend.
- On logout, the app unregisters the active push token from the backend.
- Notification taps route into the correct screen:
  - `message` -> open the room
  - `reply` -> open the exact thread
- Foreground realtime still comes from sockets. V1 does not show local
  in-app banners while the user is already active in the app.
- Thread presence is mirrored to the backend with socket events
  `open_thread` and `close_thread`.

To enable push end to end:

1. Configure the backend Firebase Admin credentials.
   - Set `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, and
     `FIREBASE_PRIVATE_KEY` on the backend for each environment.

2. Enable iOS push capabilities in Xcode for both app variants.
   - Open `ios/Runner.xcworkspace`
   - For both bundle IDs (`com.bleyachat.dev` and `com.bleyachat`), enable:
     - `Push Notifications`
     - `Background Modes` -> `Remote notifications`

3. Upload an APNs auth key to Firebase.
   - Apple Developer -> create/download an APNs Auth Key (`.p8`)
   - Firebase Console -> Project settings -> Cloud Messaging -> Apple app
   - Upload the key for each Firebase project you use

4. Test on a real device.
   - iOS simulator builds compile, but APNs push delivery requires a physical
     iPhone.
   - Android emulator/device can receive FCM once the app is installed and the
     user logs in.

5. Make sure the backend is already deployed with push enabled.
   - Mobile registration alone is not enough; the backend must have the
     Firebase Admin env vars set and running.

## Running on Android with Local Backend

For release signing, create `android/key.properties` locally (gitignored):

```properties
storeFile=/absolute/path/to/keystore.jks
storePassword=...
keyAlias=...
keyPassword=...
```

### 1) Start backend

From `../backend`:

```bash
npm run build && npm start
```

Verify backend is up:

```bash
curl http://127.0.0.1:8080/health
```

### 2) Run on Android emulator

Use Android emulator loopback (`10.0.2.2`) to reach your host machine:

```bash
flutter run --flavor dev --dart-define-from-file=config/env/dev.local.json
```

### 3) Run on physical Android device

Use your Mac LAN IP (same Wi-Fi network as the device):

```bash
flutter run --flavor dev --dart-define-from-file=config/env/dev.local.json
```

If the device cannot connect:
- Ensure backend is reachable from LAN and not blocked by a local firewall rule
- Ensure macOS firewall allows inbound connections on port `8080`
- Open `http://<LAN_IP_OF_MAC>:8080/health` in Android browser to confirm reachability

### 4) Environment defines

Available compile-time flags:
- `FLUTTER_ENV=dev|prod`
- `API_BASE_URL` (optional override for the current environment API URL)
- `GOOGLE_SERVER_CLIENT_ID`
- `GOOGLE_IOS_CLIENT_ID`
- `APPLE_SERVICE_ID`
- `APPLE_REDIRECT_URI`
- `PASSKEY_DOMAIN`

Default URLs:
- Dev: `http://127.0.0.1:8080/v1`
- Prod: `https://api.bleyachat.com/v1`

Note: Android debug/profile builds are configured to allow cleartext HTTP for local development.
Release builds should continue using HTTPS endpoints.

## Quality Checks

Run these before shipping changes:

```bash
flutter analyze
flutter test
./scripts/check_adaptive_ui.sh
```

## Building for Production

**⚠️ IMPORTANT: Always pass the production dart-defines for release builds**

### Manual Build Commands

**Android:**
```bash
# APK
flutter build apk --flavor prod --release --dart-define-from-file=config/env/prod.local.json

# App Bundle (for Play Store)
flutter build appbundle --flavor prod --release --dart-define-from-file=config/env/prod.local.json
```

**iOS:**
```bash
flutter build ios --flavor prod --release --dart-define-from-file=config/env/prod.local.json
```

### Why This Matters

Without production dart-defines:
- ❌ App may point to `localhost` instead of production API
- ❌ Google sign-in is not configured
- ❌ Dev banner may show in production
- ❌ Debug logging may be enabled

## CI/CD

**Note:** Ensure your Railway CI/CD (or other CI/CD) passes the production dart-defines, either through `--dart-define-from-file` or explicit `--dart-define` flags.

## Project Rules

Key local references:

- `rules/loading-ui-rules.md`
- `rules/theme-and-brand-rules.md`
- `rules/api-contract-rules.md`
- `lib/widgets/app_spinner.dart` for action-level loading
- `lib/widgets/app_skeleton.dart` for content loading

## Assets

Assets live under `assets/`.

## Localization

Localization resources live under `lib/src/localization`.
