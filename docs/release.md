# Release Process

This project uses local Fastlane automation for the easiest release path:

- iOS testing: App Store Connect TestFlight
- Android testing: Google Play Console internal testing
- Android live: the internal-testing build that passed the device checks is promoted to a draft production
  release, then reviewed and rolled out manually
- iOS live: use the uploaded TestFlight/App Store Connect build and submit manually

Releases are built locally with Fastlane on a Mac. There is no CI build: Bleya doesn't use Xcode Cloud (its
script was removed), so App Store Connect should have no Xcode Cloud workflow for the app.

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

1. Checks the local configuration: `config/env/prod.local.json`, `android/key.properties` and App Store
   Connect access.
2. Requires a clean git tree: every change, including new untracked files, must be committed. A build
   number then always points to the code it came from.
3. Checks that Google Play accepts the new build number, before anything is built.
4. Runs `flutter pub get`, Dart static analysis through the Flutter SDK Dart binary, and `flutter test`.
5. Builds a prod iOS IPA with `config/env/prod.local.json`.
6. Waits for the build to become available for internal testing in App Store Connect.
7. Uploads the IPA to TestFlight and assigns it to internal TestFlight groups without submitting it for external beta review.
8. Builds a prod Android AAB with `config/env/prod.local.json`.
9. Uploads the AAB to the Play Console internal testing track.
10. Writes the new build number to `pubspec.yaml` and prints the `git commit` command for it. The lane never
    commits.
11. Tags the commit the build came from as `build/N`, locally.

If the iOS upload succeeds but the lane fails later, rerunning the same release
reuses the existing App Store Connect build instead of trying to upload the
same build number again. That only happens when nothing was committed since
that upload. If you committed a fix in between, the lane stops before building:
set `pubspec.yaml` to the number already on TestFlight, commit it and run the
lane again, and both platforms get the next number.

After a successful run, `git status` shows only the `pubspec.yaml` version bump. Commit it with the
printed command before the next release build. If the iOS build updated `ios/Podfile.lock` (it does when the
native plugins change), commit that too. The next build lane refuses to run until the tree is clean.

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
version: 1.0.0+11
```

becomes:

```text
version: 1.0.0+12
```

Fastlane writes the new number back to `pubspec.yaml` only after the last
upload of the lane: after both uploads in `testing`, after its one upload in
`ios_testflight` or `android_internal`. If the release fails before that point,
the next retry uses the same build number instead of skipping one. The write
is never committed for you: the lane prints the `git commit` command, and the
next build lane refuses to run until it is committed.

The single-platform lanes write the number back too, so the other platform's
next build uses the number after it. That's fine: each store only needs its own
build numbers to go up.

The version before `+` is the user-visible app version. The number after `+` is
the iOS build number and Android version code.

Override manually when needed:

```sh
RELEASE_BUILD_NAME=1.0.1 RELEASE_BUILD_NUMBER=20 bundle exec fastlane testing
```

An override is used as given. Afterwards, `pubspec.yaml` moves up to it if it's
higher than the number there, and it never moves down.

Before anything is built, `testing` and `android_internal` check that the
number is higher than the newest version code on the Play internal track, so a
taken number fails in seconds instead of after the build.

## Build Tags

`testing`, `ios_testflight` and `android_internal` tag the commit each build
came from as `build/N` (an annotated tag, for example `build/12`, "Bleya 1.0.0 (12)").
The tags stay local; push them when convenient:

```sh
git push origin build/12
```

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

Promote the Android build that passed the device checks to a draft production
release, without rebuilding (see Going Live):

```sh
bundle exec fastlane android_promote_production version_code:12
```

Check the promotion with Google Play without changing anything:

```sh
bundle exec fastlane android_promote_production version_code:12 validate_only:true
```

Skip analysis and tests if you already ran them:

```sh
SKIP_CHECKS=1 bundle exec fastlane testing
```

`SKIP_CHECKS` doesn't skip the clean-tree check: every build lane still
requires committed code.

## After Uploading

Commit the version bump with the command the lane printed.

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

1. Note the version code that passed the device checks. It must still be the
   release on the internal testing track: uploading a newer internal build
   replaces it there.
2. Optionally check the promotion first:
   `bundle exec fastlane android_promote_production version_code:N validate_only:true`.
3. Run `bundle exec fastlane android_promote_production version_code:N`. It
   promotes that exact build to a draft production release. Nothing is rebuilt
   or uploaded, so production gets the binary that was tested. Without
   `version_code`, the lane lists the internal track's version codes and stops.
   A promotion replaces any production draft already there.
4. Complete any required Play Console items: Data safety, content rating, the
   app category (Communication) and the store listing. See
   `docs/store-privacy-answers.md`.
5. Review the draft production release and roll it out manually.

iOS:

1. Use the same uploaded build that passed the device checks in App Store Connect.
2. Complete app metadata, screenshots, privacy, age rating, and review notes.
3. Submit for App Review manually.

Manual review for live release is intentional for now. It avoids accidentally
shipping to real users before store metadata and policy declarations are correct.

## Troubleshooting

If `bundle exec fastlane ...` says Fastlane is missing:

```sh
bundle install
```

If a lane stops with "Release builds are made only from committed code", it
lists the uncommitted and untracked files. Commit them (after a release, that's
usually the `pubspec.yaml` version bump), then run the lane again.

If `flutter analyze` crashes on this machine, the lane uses:

```sh
$HOME/flutter/bin/dart analyze
```

Override it if your Flutter SDK is elsewhere:

```sh
DART_BIN=/path/to/flutter/bin/dart bundle exec fastlane testing
```

If a lane stops because the build is already on TestFlight but was uploaded
before your latest commit, set `version:` in `pubspec.yaml` to that build
number, commit it and run the lane again. Both platforms then get the next one.

If Play Console rejects a build:

- Confirm the AAB package is `com.bleyachat`.
- Confirm the build number is higher than every previous upload. The lane
  checks the internal track before building; if it stops there, set
  `pubspec.yaml` to the number it names, commit it and run it again.
- Confirm `android/key.properties` points to the upload key registered with Play.
- If Google Play App Signing is enabled, make sure Firebase has the Play signing
  SHA-1 for Google Sign-In.

If TestFlight rejects a build:

- Confirm the App Store Connect app uses bundle ID `com.bleyachat`.
- Confirm signing/provisioning uses the Apple team `S7V679NZ3B`.
- Confirm the build number is higher than every previous upload.
- Confirm production Firebase and APNs settings are in place.
