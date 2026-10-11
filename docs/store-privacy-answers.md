# Store Privacy Answers — App Store "App Privacy", Google Play "Data safety" and app category

**Last updated:** October 11, 2026, for first-party analytics, the install ID and Crashlytics. These answers follow
the privacy policy at bleyachat.com/privacy and the current code. Update both together when data handling changes.

Facts they rest on:
- No advertising or tracking SDKs. The Firebase SDKs are Cloud Messaging (push) and Crashlytics (crash reports).
- Analytics are first-party: they go only to our backend (bleya-backend `docs/analytics.md`). The app reports app
  opens and sign-in attempts that end before reaching the backend (started, cancelled, failed in the provider's
  sheet). The backend records sign-in outcomes, content-filter rejections (which field, never the content) and one
  record per user per day they used the app, with platform and app version. All of it is linked to the account
  when the user is signed in, deleted after 90 days and with the account, and included in the data export. Only
  daily totals (counts, no personal data) are kept longer.
- Install ID: a random UUID the app creates on first launch, kept in the app's own storage (gone on uninstall) and
  sent with every request. It is not the advertising ID or the IDFV, and it isn't shared.
- Crashlytics (release builds) sends crash and error reports: stack traces, device model, OS and app version,
  device state (memory, storage), Crashlytics/Firebase installation IDs, and the signed-in account ID. Google
  processes them for us as a service provider and keeps them 90 days.
- Sign-in is Google, Apple or a passkey. Google/Apple give us an account ID and an email address.
- Location: the device's coordinates are sent once to find nearby city rooms. They are not stored, and the server
  logs redact them.
- Uploaded profile photos get an automated safety check by Sightengine, a service provider acting for us.
- All traffic is HTTPS/WSS. Users can delete their account in the app (Settings → Delete account) or at
  https://bleyachat.com/delete-account.

## App Store Connect → App Privacy

**Do you or your third-party partners collect data from this app?** Yes.
**Is any data used to track users?** No.

Data types to declare. For each: **linked to the user: Yes** and **used for tracking: No**, with these purposes
(Apple's definitions: App Functionality includes "authenticate the user", "implement security measures" and
"minimize app crashes"; Analytics is "evaluate user behavior … or measure audience size"):

| Category | Data type | What it is | Purposes |
|---|---|---|---|
| Contact Info | Email Address | Email from Google/Apple sign-in | App Functionality |
| Identifiers | User ID | Account ID; Google/Apple account ID; username. The account ID is also on analytics records and crash reports | App Functionality, Analytics |
| Identifiers | Device ID | The install ID; the push token; Crashlytics/Firebase installation IDs | App Functionality, Analytics |
| User Content | Photos or Videos | Profile photo | App Functionality |
| User Content | Other User Content | Messages, bio, reports | App Functionality |
| Usage Data | Product Interaction | App opens, sign-in attempts and outcomes, days the app was used, content-filter rejections | Analytics, App Functionality |
| Diagnostics | Crash Data | Crashlytics crash reports | App Functionality |
| Diagnostics | Other Diagnostic Data | Device state and app version sent with crash and error reports; sign-in error codes | App Functionality, Analytics |

Apple counts data as linked when it is tied to the account, device or other identity, and anything that is personal
data under privacy law (GDPR) is linked. Everything above carries the account ID or the install ID, so all of it is
linked. Nothing is tracking: no data is combined with other companies' data for advertising or shared with data
brokers.

The app's privacy manifest, `ios/Runner/PrivacyInfo.xcprivacy`, declares exactly this table (the same eight types
and purposes, linked, not tracking), so Xcode's privacy report for an archive matches it. Change both together;
`test/config/platform_config_test.dart` checks the manifest. The Firebase SDKs ship their own manifests, which show
as not linked in the privacy report; that is expected, because they don't know about the account ID the app adds.
After archiving, check Organizer → Generate Privacy Report against this table.

Don't declare:
- **Location.** The coordinates are used for one real-time request and not stored. Apple doesn't count data
  handled only to serve a request in real time as collected.
- **Performance Data.** Nothing measures launch time, hang rate or energy use (Crashlytics doesn't).
- **Other Usage Data.** Product Interaction covers every usage record.
- **Purchases, Contacts, Browsing/Search History, Health, Financial, Sensitive Info.** None of these are collected.

## Google Play Console → Data safety

**Submitted on September 30, 2026** through the Play Developer API (`applications.dataSafety`) with
`docs/google-play-data-safety.csv`, Google's full question list with our answers. **Changed on October 11, 2026 for
analytics, the install ID and Crashlytics; not uploaded yet.** To change the answers, edit that file (or export a
fresh one from Play Console) and upload it again, in Play Console (App content → Data safety → Import from CSV) or
with the same API call. An import replaces every answer, so if anything was changed in Play Console since the last
upload, export first and compare.

**Does your app collect or share any of the required user data types?** Yes.
**Is all of the user data collected by your app encrypted in transit?** Yes.
**Account creation:** OAuth (Sign in with Google or Apple).
**Account deletion link:** https://bleyachat.com/delete-account
**Can users ask to delete some of their data without deleting the account?** Yes:
https://bleyachat.com/delete-account#delete-some-data

**Data shared:** None. The hosting, storage, push, crash-reporting (Firebase Crashlytics), email and image-check
providers are service providers acting for us, which Google doesn't count as sharing, and messages go to other users
because the user sends them.

Data collected. Every row is **Collected: Yes, Shared: No**, and not processed ephemerally unless it says so.
Users can't turn off analytics or crash reporting, so those types are **Required**.

| Category | Data type | Required or optional | Purpose |
|---|---|---|---|
| Location | Precise location | Optional (location permission); **processed ephemerally: Yes** | App functionality |
| Personal info | Name (the username; Google counts a nickname as a name) | Required | App functionality, Account management |
| Personal info | Email address | Required | Account management |
| Personal info | User IDs (also on analytics records and crash reports) | Required | App functionality, Analytics, Account management |
| Photos and videos | Photos | Optional | App functionality |
| Messages | Other in-app messages | Optional | App functionality |
| App activity | App interactions (app opens, sign-in attempts and outcomes, days the app was used) | Required | Analytics |
| App activity | Other user-generated content (bio, reports) | Optional | App functionality, Fraud prevention, security, and compliance |
| App activity | Other actions (rooms joined, blocks, read markers, content-filter rejections) | Optional | App functionality, Analytics |
| App info and performance | Crash logs (Crashlytics) | Required | Analytics |
| App info and performance | Diagnostics (device state and app version with crash and error reports) | Required | Analytics |
| Device or other IDs | Device or other IDs (push token, registered even without notification permission; the install ID; Crashlytics/Firebase installation IDs) | Required | App functionality, Analytics |

Google's Analytics purpose explicitly includes "to monitor app health, to diagnose and fix bugs or crashes", so crash
logs and diagnostics are Analytics. The install ID is only used to count sign-in attempts per install, not for rate
limits or blocking, so it isn't declared for fraud prevention.

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

## When to submit

The backend has been recording sign-in outcomes, content-filter rejections and days of use with the account ID since
it was deployed on October 11, 2026, also for app builds already in the stores. So update both forms now, not with
the next build: App Store answers can be changed at any time without a new build (App Store Connect → App Privacy →
Edit, then Publish), and the Play CSV can be imported at any time. The install ID, app events and Crashlytics start
with the next build; declaring them a little early is the safe side.

## When this changes

- **New analytics events, a new SDK (for example Google Analytics or Performance Monitoring) or a new purpose:**
  both forms, the privacy manifest and the privacy policy change together.
- **Random or anonymous matching added, or a move to the Social or Dating category:** the Child Safety Standards
  policy applies, and Play needs published standards and the declaration before the next release.
