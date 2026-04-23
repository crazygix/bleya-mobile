# Release Process

This project uses local Fastlane automation for the easiest release path:

- iOS testing: App Store Connect TestFlight
- Android testing: Google Play Console internal testing
- Android live: draft production release created by Fastlane, then manually reviewed
- iOS live: use the uploaded TestFlight/App Store Connect build and submit manually

The main one-click command is:

```sh
bundle exec fastlane testing
```

In Cursor or VS Code, run the existing Run and Debug configuration:

```text
Mobile release
```

## What The Testing Lane Does

`Mobile release` runs `bundle exec fastlane testing`, which does this in order:

1. Runs `flutter pub get`.
2. Runs Dart static analysis through the Flutter SDK Dart binary.
3. Runs `flutter test`.
4. Builds a prod iOS IPA with `config/env/prod.local.json`.
5. Waits for the build to become available for internal testing in App Store Connect.
6. Uploads the IPA to TestFlight and assigns it to internal TestFlight groups without submitting it for external beta review.
7. Builds a prod Android AAB with `config/env/prod.local.json`.
8. Uploads the AAB to the Play Console internal testing track.

If the iOS upload succeeds but the lane fails later, rerunning the same release
reuses the existing App Store Connect build instead of trying to upload the
same build number again.

The app IDs used by the release lane are:

- iOS bundle ID: `com.bleyachat`
- Android package: `com.bleyachat`
- Flutter flavor/scheme: `prod`
- Dart defines file: `config/env/prod.local.json`

## First-Time Setup

Install Fastlane dependencies:

```sh
cd ~/Development/bleya/mobile
bundle install
```

This machine already has a local `fastlane/.env` scaffold. If it is missing on
another machine, recreate it with:

```sh
mkdir -p fastlane/secrets
cp fastlane/.env.example fastlane/.env
```

`fastlane/.env` and `fastlane/secrets/` are gitignored. Do not commit real keys.

## App Store Connect Setup

Create an App Store Connect API key:

1. Open App Store Connect.
2. Go to Users and Access.
3. Open Integrations.
4. Open App Store Connect API.
5. Create a Team API key.
6. Give it enough access to upload builds for Bleya.
7. Download the `.p8` file once and store it under `fastlane/secrets/`.
8. Copy the Key ID and Issuer ID into `fastlane/.env`.

Example:

```sh
APP_STORE_CONNECT_KEY_ID=ABC123DEFG
APP_STORE_CONNECT_ISSUER_ID=00000000-0000-0000-0000-000000000000
APP_STORE_CONNECT_KEY_FILEPATH=fastlane/secrets/AuthKey_ABC123DEFG.p8
```

This must be an App Store Connect API key. It is different from the Apple
Developer APNs `.p8` key used for push notifications.

Some individual App Store Connect API keys do not have an issuer ID. In that
case, leave `APP_STORE_CONNECT_ISSUER_ID` blank. Team API keys usually require
the issuer ID shown on the App Store Connect API page.

Alternative: create a Fastlane API key JSON and set:

```sh
APP_STORE_CONNECT_API_KEY_PATH=fastlane/secrets/app-store-connect-api-key.json
```

Make sure App Store Connect already has an app record for:

```text
com.bleyachat
```

Internal TestFlight testers are managed in App Store Connect.

If `TESTFLIGHT_GROUPS` is not set, Fastlane assigns the uploaded build to all
internal TestFlight groups it finds for the app. If you want strict control, set
comma-separated group names in `fastlane/.env`:

```sh
TESTFLIGHT_GROUPS=App Store Connect Users
```

If an internal group is configured in App Store Connect with access to all
builds, Apple rejects explicit build assignment for that group. The release lane
detects that case and skips assignment because those testers already see every
processed internal build automatically.

## Google Play Setup

Create a Play Console service account JSON:

1. Open Play Console.
2. Go to Setup -> API access.
3. Link or open the Google Cloud project used by Play Console.
4. Create a service account.
5. Grant access to the Bleya app with release permissions.
6. Download the JSON key.
7. Store it at `fastlane/secrets/google-play-service-account.json`.
8. Set this in `fastlane/.env`:

```sh
GOOGLE_PLAY_JSON_KEY=fastlane/secrets/google-play-service-account.json
```

Enable the Google Play Android Developer API for the same Google Cloud project
used by that service account:

```text
https://console.developers.google.com/apis/api/androidpublisher.googleapis.com/overview
```

If you just enabled it, wait a few minutes before retrying the upload.

Make sure Play Console already has an app record for:

```text
com.bleyachat
```

Internal testers are managed under Testing -> Internal testing.

For a brand-new Play Console app, Google may reject an internal upload with:

```text
Only releases with status draft may be created on draft app.
```

The release lane handles that automatically by retrying the internal upload as a
draft release. After the first upload, finish the remaining Play Console app
setup and publish from the console when Google requires it.

## Android Signing

The release lane requires:

```text
android/key.properties
```

Expected format:

```properties
storeFile=/absolute/path/to/keystore.jks
storePassword=...
keyAlias=...
keyPassword=...
```

This file is gitignored.

## Build Numbers

Every App Store Connect and Play Console upload needs a new build number.

By default, Fastlane reads the build number from `pubspec.yaml`, increments it
by one for the build it is creating, and uses the same new build number for both
iOS and Android.

```text
version: 0.0.1+1
```

becomes:

```text
version: 0.0.1+2
```

Fastlane writes the new number back to `pubspec.yaml` only after TestFlight
accepts and distributes the build. If the release fails before that point, the
next retry uses the same next build number instead of skipping one.

The version before `+` is the user-visible app version. The number after `+` is
the iOS build number and Android version code.

Override manually when needed:

```sh
RELEASE_BUILD_NAME=0.1.0 RELEASE_BUILD_NUMBER=2 bundle exec fastlane testing
```

Manual overrides do not edit `pubspec.yaml`.

## Commands

Build both prod artifacts without uploading:

```sh
bundle exec fastlane build_prod
```

Upload only iOS to TestFlight:

```sh
bundle exec fastlane ios_testflight
```

Upload only Android to internal testing:

```sh
bundle exec fastlane android_internal
```

Upload both testing builds:

```sh
bundle exec fastlane testing
```

Create an Android draft production release:

```sh
bundle exec fastlane android_production_draft
```

Skip checks if you already ran them:

```sh
SKIP_CHECKS=1 bundle exec fastlane testing
```

## After Uploading

TestFlight:

1. Wait for App Store Connect processing.
2. Open TestFlight for the Bleya app.
3. Confirm the build was auto-assigned to the internal testing group.
4. Add testers if needed.

Play Console internal testing:

1. Open Testing -> Internal testing.
2. Confirm the release is available to testers.
3. Add tester emails or tester group if needed.
4. Share the opt-in/internal testing link.

## Going Live Later

Android:

1. Run `bundle exec fastlane android_production_draft`.
2. Open Play Console.
3. Review the draft production release.
4. Complete any required Data safety, content rating, policy, or store listing items.
5. Submit/roll out manually.

iOS:

1. Use the same uploaded build in App Store Connect.
2. Complete app metadata, screenshots, privacy, age rating, and review notes.
3. Submit for App Review manually.

Manual review for live release is intentional for now. It avoids accidentally
shipping to real users before store metadata and policy declarations are correct.

## Troubleshooting

If `bundle exec fastlane ...` says Fastlane is missing:

```sh
bundle install
```

If `flutter analyze` crashes on this machine, the lane uses:

```sh
$HOME/flutter/bin/dart analyze
```

Override it if your Flutter SDK is elsewhere:

```sh
DART_BIN=/path/to/flutter/bin/dart bundle exec fastlane testing
```

If Play Console rejects a build:

- Confirm the AAB package is `com.bleyachat`.
- Confirm the build number is higher than every previous upload.
- Confirm `android/key.properties` points to the upload key registered with Play.
- If Google Play App Signing is enabled, make sure Firebase has the Play signing
  SHA-1 for Google Sign-In.

If TestFlight rejects a build:

- Confirm the App Store Connect app uses bundle ID `com.bleyachat`.
- Confirm signing/provisioning uses the Apple team `S7V679NZ3B`.
- Confirm the build number is higher than every previous upload.
- Confirm production Firebase and APNs settings are in place.
