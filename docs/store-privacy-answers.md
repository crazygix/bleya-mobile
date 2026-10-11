# Store Privacy Answers — App Store "App Privacy", Google Play "Data safety" and app category

**Last updated:** October 11, 2026, for first-party analytics, the install ID and Crashlytics. These answers follow
the privacy policy at bleyachat.com/privacy and the current code. Update both together when data handling changes.

Facts they rest on:
- No advertising or tracking SDKs. The Firebase SDKs are Cloud Messaging (push) and Crashlytics (crash reports).
- Our analytics events go only to our backend (bleya-backend `docs/analytics.md`). The app reports app
  opens and sign-in attempts that end before reaching the backend (started, cancelled, failed in the provider's
  sheet). The backend records sign-in outcomes, content-filter rejections (which field, never the content) and one
  record per user per day they used the app, with platform and app version. All of it is deleted after 90 days.
  Records with the account ID (everything while signed in) are also deleted with the account and included in the
  data export; records from before sign-in carry only the install ID and expire after 90 days. Only daily totals
  (counts, no personal data) are kept longer.
- Install ID: a random UUID the app creates on first launch, kept in the app's own storage (gone on uninstall; on
  iOS a restored device backup brings it back) and sent with every request. While signed in it is stored next to
  the account ID, and it stays the same after signing out. It is not the advertising ID or the IDFV, and it isn't
  shared.
- Crashlytics (release builds) sends crash and error reports: stack traces, device model, OS and app version,
  device state (memory, storage), Crashlytics/Firebase installation IDs, and the signed-in account ID. Through
  Firebase Sessions, which Crashlytics includes, it also sends a session-start event (session ID, Firebase
  installation ID, device model, OS and app version, network type) each time the app is opened, so Crashlytics can
  count the users a crash affects. Google processes them for us as a service provider and keeps them 90 days.
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
| Usage Data | Product Interaction | App opens, sign-in attempts and outcomes, days the app was used, content-filter rejections; session starts sent by Crashlytics (Firebase Sessions) | Analytics, App Functionality |
| Diagnostics | Crash Data | Crashlytics crash reports | App Functionality |
| Diagnostics | Other Diagnostic Data | Device state and app version sent with crash and error reports; sign-in error codes and messages | App Functionality, Analytics |

Apple counts data as linked when it is tied to the account, device or other identity, and anything that is personal
data under privacy law (GDPR) is linked. Everything above carries the account ID or the install ID, so all of it is
linked. Nothing is tracking: no data is combined with other companies' data for advertising or shared with data
brokers.

The app's privacy manifest, `ios/Runner/PrivacyInfo.xcprivacy`, declares exactly this table (the same eight types
and purposes, linked, not tracking), so Xcode's privacy report for an archive matches it. Change both together;
`test/config/platform_config_test.dart` checks the manifest. The Firebase SDKs ship their own manifests, which show
as not linked in the privacy report; that is expected, because they don't know about the account ID the app adds.
After archiving, check Organizer → Generate Privacy Report against this table. The report also lists Other Data
Types (Analytics) from FirebaseMessaging's manifest: FCM delivery metrics, which are only sent through Google
Analytics or a notification service extension that calls `exportDeliveryMetricsToBigQuery`. Bleya has neither, so
it isn't declared; declare it if either is added.

Don't declare:
- **Location.** The coordinates are used for one real-time request and not stored. Apple doesn't count data
  handled only to serve a request in real time as collected.
- **Performance Data.** Nothing measures launch time, hang rate or energy use (Crashlytics doesn't).
- **Other Usage Data.** Product Interaction covers every usage record.
- **Other Data Types.** Only FirebaseMessaging's delivery metrics would count, and the app doesn't send them (see
  above).
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

**Data shared:** None. The hosting, storage, push, crash-reporting (Firebase Crashlytics), email, image-check and
internal-alerting (Telegram: moderation alerts and server error reports, which can contain an account ID; the daily
digest has counts only) providers are service providers acting for us, which Google doesn't count as sharing, and
messages go to other users because the user sends them.

Data collected. Every row is **Collected: Yes, Shared: No**, and not processed ephemerally unless it says so.
Users can't turn off analytics or crash reporting, so those types are **Required**.

| Category | Data type | Required or optional | Purpose |
|---|---|---|---|
| Location | Precise location | Optional (location permission); **processed ephemerally: Yes** | App functionality |
| Personal info | Name (the username; Google counts a nickname as a name) | Required | App functionality, Account management |
| Personal info | Email address | Required | Account management |
| Personal info | User IDs (also on analytics records and crash reports; a banned account's Google/Apple ID is kept as a keyed hash to stop re-registration) | Required | App functionality, Analytics, Fraud prevention, security, and compliance, Account management |
| Photos and videos | Photos (profile photos get an automated safety check) | Optional | App functionality, Fraud prevention, security, and compliance |
| Messages | Other in-app messages (a reported message is copied into the report) | Optional | App functionality, Fraud prevention, security, and compliance |
| App activity | App interactions (app opens, sign-in attempts and outcomes, days the app was used; session starts sent by Crashlytics) | Required | Analytics |
| App activity | Other user-generated content (bio, reports) | Optional | App functionality, Fraud prevention, security, and compliance |
| App activity | Other actions (rooms joined, blocks, read markers, content-filter rejections; many blocks of one account alert moderators) | Optional | App functionality, Analytics, Fraud prevention, security, and compliance |
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
the next build.

- **App Store:** Apple wants the answers to match the version on sale, so publish now what the backend already
  collects: User ID (with Analytics), Product Interaction, Other Diagnostic Data and Device ID (the push token).
  Add Crash Data, and the Crashlytics and install-ID parts of the descriptions, when the build with Crashlytics is
  released. Answers can be changed at any time without a new build (App Store Connect → App Privacy → Edit, then
  Publish). The privacy manifest ships with that build.
- **Google Play:** import the CSV now. Play has no per-version answers, and declaring the next build's crash logs
  a little early is the safe side.

## When this changes

- **New analytics events, a new SDK (for example Google Analytics or Performance Monitoring) or a new purpose:**
  both forms, the privacy manifest and the privacy policy change together.
- **Random or anonymous matching added, or a move to the Social or Dating category:** the Child Safety Standards
  policy applies, and Play needs published standards and the declaration before the next release.
