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
flutter run --dart-define-from-file=config/env/dev.local.json
```

## Run from Cursor (Multi-root Workspace)

1) Open [bleya.code-workspace](/Users/ivan.kokanovic/Development/bleya/mobile/bleya.code-workspace) in Cursor.
2) Run task `Backend: Start Dev Server`.
3) Start your Android emulator or iOS simulator/device.
4) Run command `Flutter: Select Device` and pick Android or iOS.
5) In Run and Debug, launch `Mobile dev`.

Notes:
- Workspace launch config is the single source of truth for Flutter runs.
- `Mobile dev` reads `config/env/dev.local.json` via `--dart-define-from-file`.
- `Mobile prod`/`Mobile release` can use `config/env/prod.local.json` for local production overrides.
- If your LAN IP changes, update `API_BASE_URL` in `config/env/dev.local.json` only.
- `Mobile prod`/`Mobile release` read `config/env/prod.example.json`.
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
flutter run --dart-define-from-file=config/env/dev.local.json
```

### 3) Run on physical Android device

Use your Mac LAN IP (same Wi-Fi network as the device):

```bash
flutter run --dart-define-from-file=config/env/dev.local.json
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
flutter build apk --release --dart-define-from-file=config/env/prod.local.json

# App Bundle (for Play Store)
flutter build appbundle --release --dart-define-from-file=config/env/prod.local.json
```

**iOS:**
```bash
flutter build ios --release --dart-define-from-file=config/env/prod.local.json
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
