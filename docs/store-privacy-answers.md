# Store Privacy Answers — App Store "App Privacy", Google Play "Data safety" and app category

**Last updated:** October 2, 2026. These answers follow the privacy policy at bleyachat.com/privacy and the
current code. Update both together when data handling changes.

Facts they rest on:
- No advertising, analytics, crash-reporting or tracking SDKs. The only Firebase SDK is Cloud Messaging.
- Sign-in is Google, Apple or a passkey. Google/Apple give us an account ID and an email address.
- Location: the device's coordinates are sent once to find nearby city rooms. They are not stored, and the server
  logs redact them.
- Uploaded profile photos get an automated safety check by Sightengine, a service provider acting for us.
- All traffic is HTTPS/WSS. Users can delete their account in the app (Settings → Delete account) or at
  https://bleyachat.com/delete-account.

## App Store Connect → App Privacy

**Do you or your third-party partners collect data from this app?** Yes.
**Is any data used to track users?** No.

Data types to declare. For each: **linked to the user: Yes**, **used for tracking: No**, **purpose: App
Functionality**. For the email and user ID, also tick **Other Purposes** only if you use them for more than the
account (today: don't).

| Category | Data type | What it is |
|---|---|---|
| Contact Info | Email Address | Email from Google/Apple sign-in |
| Identifiers | User ID | Account ID; Google/Apple account ID; username |
| User Content | Photos or Videos | Profile photo |
| User Content | Other User Content | Messages, bio, reports |

The app's privacy manifest, `ios/Runner/PrivacyInfo.xcprivacy`, declares exactly this table (the same four types,
linked, not tracking, App Functionality), so Xcode's privacy report for an archive matches it. Change both together;
`test/config/platform_config_test.dart` checks the manifest.

Don't declare:
- **Location.** The coordinates are used for one real-time request and not stored. Apple doesn't count data
  handled only to serve a request in real time as collected.
- **Device ID.** The push token isn't a device or advertising ID.
- **Diagnostics, Usage Data, Purchases, Contacts, Browsing/Search History, Health, Financial, Sensitive Info.**
  None of these are collected.

## Google Play Console → Data safety

**Submitted on September 30, 2026** through the Play Developer API (`applications.dataSafety`) with
`docs/google-play-data-safety.csv`, Google's full question list with our answers. To change the answers, edit
that file (or export a fresh one from Play Console) and upload it again, in Play Console (App content → Data
safety → Import from CSV) or with the same API call.

**Does your app collect or share any of the required user data types?** Yes.
**Is all of the user data collected by your app encrypted in transit?** Yes.
**Account creation:** OAuth (Sign in with Google or Apple).
**Account deletion link:** https://bleyachat.com/delete-account
**Can users ask to delete some of their data without deleting the account?** Yes:
https://bleyachat.com/delete-account#delete-some-data

**Data shared:** None. The hosting, storage, push, email and image-check providers are service providers acting
for us, which Google doesn't count as sharing, and messages go to other users because the user sends them.

Data collected. Every row is **Collected: Yes, Shared: No**.

| Category | Data type | Required or optional | Purpose |
|---|---|---|---|
| Location | Precise location | Optional (location permission); **processed ephemerally: Yes** | App functionality |
| Personal info | Name (the username; Google counts a nickname as a name) | Required | App functionality, Account management |
| Personal info | Email address | Required | Account management |
| Personal info | User IDs | Required | App functionality, Account management |
| Photos and videos | Photos | Optional | App functionality |
| Messages | Other in-app messages | Optional | App functionality |
| App activity | Other user-generated content (bio, reports) | Optional | App functionality, Fraud prevention, security, and compliance |
| App activity | Other actions (rooms joined, blocks, read markers) | Optional | App functionality |
| Device or other IDs | Device or other IDs (push token; registered even without notification permission) | Required | App functionality |

Location is declared here, unlike on the App Store, because Play's form has an explicit "processed ephemerally" answer
for it. Declaring it that way is the conservative choice.

## Google Play Console → App category and child safety

**Category: Communication** (Store presence → Store settings), decided on October 1, 2026, as for most chat apps
(WhatsApp, Telegram, Discord).

- Google's Child Safety Standards policy covers apps in the Social and Dating categories, and anonymous or random
  chat apps. Bleya shows usernames and profiles and doesn't match strangers at random, so under Communication the
  policy most likely doesn't apply. For now there is no published standards page, no declaration and no reporting
  procedure.
- Google decides the scope. If Play Console still asks for the Child safety standards declaration (Policy and
  programs → App content), publish the short Terms section from the fix plan
  (`docs/ultrareview-fix-plan/2-your-checklist.md`, "If Play asks: minimal child-safety section"), then fill in the
  declaration with that URL and a contact.

## When this changes

- **Any analytics or crash reporting added:** both forms change (App Store: Diagnostics/Usage Data; Play: App
  info and performance / App activity).
- **Random or anonymous matching added, or a move to the Social or Dating category:** the Child Safety Standards
  policy applies, and Play needs published standards and the declaration before the next release.
