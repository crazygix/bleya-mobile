# Mobile ultrareview fix plan — 2. Your checklist

**Last updated:** October 1, 2026

This is everything in the fix plan that only you can do: console and account work, approvals, and the device checks once the fixes are in. It goes with [1-app-fixes.md](1-app-fixes.md), which covers what I change in the app and on the website, and [3-backend-changes.md](3-backend-changes.md), which covers what changes on the server.

## 1. Your decisions (October 1, 2026)

**Taken as recommended**
- The app disconnects as soon as it goes to the background.
- Refresh-token grace: the old token keeps working until the new one is used, at most 7 days, with a 30 s window (BE2).
- A plain logout keeps the "Sign in with Passkey" button; only account deletion clears it.
- `/auth/logout` switches off the account's push token (BE3), and the app stops calling `/notifications/push/unregister`.
- Ask for notification permission the first time the chat list shows.
- Every push plays a sound on iPhone.
- Pushes go to one device per account for launch.
- The debug key is removed from production passkey trust, and the upload key stays until you rotate it.
- The backend logs a warning at startup if the passkey origins look wrong.
- The new sign-in error copy is approved.
- On Android, back during the Activity spinner cancels the open, and Activity items whose message is gone are removed.
- The offline strip pushes the screen down.
- `applinks` comes out of both the app and the website.
- No Licenses row in Settings.
- Release lanes tag builds as `build/N`, track `ios/Podfile.lock`, and print the commit command instead of committing.

**Your alternatives**
- **Chat-open error** after **10 s** (not 15 s).
- **A push for the chat that's already open** doesn't open a second screen.
- **Blocking a thread's first author** leaves the thread open.
- **A failed automatic passkey offer** shows "You can add a passkey later in Settings."
- **No character counter** in the message box. An over-limit restored draft shows "Messages can be up to 2,000 characters." when you try to send it.
- **Both the iOS app-icon badge and Android's extra permission dialog** are built now (C1, C3, BE9).
- **The badge counts** unread Activity items plus DMs with unread messages; city rooms don't count. Tell me if you want a different count.
- **Child safety:** Bleya goes under **Communication** on Google Play. No Terms section, declaration or reporting procedure for now. If Play still asks, we use the [minimal section](#if-play-asks-minimal-child-safety-section).
- **Profile-photo checks** stay as they are, and `CONTENT_BLOCKLIST` stays as it is.

## 2. Do before I start

- [ ] **Commit the four files you have open**: `pubspec.yaml` (1.0.0+11), `fastlane/Fastfile` (the agreement hint), `android/settings.gradle` and `android/gradle/wrapper/gradle-wrapper.properties` (AGP 8.9.1 / Gradle 8.11.1). Build 11 was built from them, so tag the commit `build/11`. You can also tell me to do it.
- [ ] **Commit this plan folder** (`docs/ultrareview-fix-plan/`), or tell me to. The new release lanes refuse to build while there are uncommitted or untracked files.
- [ ] **Play app-signing key:** in Play Console → Test and release → App integrity → App signing, copy the *App signing key certificate* SHA-256.
  - Its SHA-1 on the same card should be `C7:00:05:50:98:47:56:D3:F0:0F:58:E8:C7:53:05:AB:F0:5E:13:D5`, the one already in the prod `google-services.json`.
  - The *Upload key* SHA-256 should start with `7E:B2:01:C0`.
- [ ] **Play listing** (H3): set the app category to **Communication** (Store presence → Store settings). Check that App content doesn't ask for a Child safety standards declaration.
- [ ] **Play account:** confirm the developer account is an organization account for Readyque DOO. A personal account created after November 2023 must run a closed test (12 testers for 14 days) before it can publish to production.
- [ ] **Xcode Cloud:** in App Store Connect → Xcode Cloud, delete any Bleya workflow. Its script is being removed (G3).

## 3. While I work

- [ ] **Approve each backend deploy** in the order in [3-backend-changes.md](3-backend-changes.md#deploy-order). The backend goes first; it works with build 11.
- [ ] **Smoke-test on build 11** after each backend deploy:
  - open a city room, a DM and a thread from Activity;
  - send and reply;
  - log out and back in.

  Everything should behave as before.
- [ ] **Railway → backend → Variables:** set `PASSKEY_EXPECTED_ORIGINS` to the value in BE7, once I've computed the Play origin from your SHA-256 (or let me set it with the Railway CLI). Do this **before** the website deploy.
- [ ] **Website deploy** (`wrangler deploy` from `bleya/website`): assetlinks.json and apple-app-site-association.
  - Afterwards, check that this URL reports `"linked": true`:
    `https://digitalassetlinks.googleapis.com/v1/assetlinks:check?source.web.site=https://bleyachat.com&relation=delegate_permission/common.get_login_creds&target.android_app.package_name=com.bleyachat&target.android_app.certificate.sha256_fingerprint=<PLAY_SHA256>`
  - Google caches Digital Asset Links, so a phone may keep refusing passkeys for a while; wait until that check says `linked` before testing.
  - Apple's copy at `https://app-site-association.cdn-apple.com/a/v1/bleyachat.com` drops `applinks` within a day or two.
- [ ] **Look:** sign off the new background from side-by-side screenshots (F7).

## 4. After the fixes: device checks

Test the new build (1.0.0+12, from `bundle exec fastlane testing`) on an iPhone and an Android 13+ phone, plus an Android 12 or older device or emulator if you have one. Use a separate test account on each device, since the server keeps one push token per account. Some checks need the admin key.

### Chats, threads and background (release blockers 1 and 2)
- [ ] **Wrong room.** On phone A, start a thread in a city room by posting a message. Open a DM and put the app in the background. On phone B, reply in that thread, then tap the push on phone A. Read the thread, go back and send in the DM. The message appears only in the DM (check the city room on phone B), with no "That reply belongs to a different chat." message. (A1, A2, BE1)
- [ ] **Say hey.** City room → tap a username → Say hey → back. Messages from another phone in the city room appear live without you sending anything, and its unread badge doesn't grow while it's open. (A1, A2)
- [ ] **Thread from Activity.** Activity → open a reply's thread → back → Chats → open that room: the history loads. Leave the room screen and post there from another phone: the push arrives. (A1, A2)
- [ ] **Push for the open chat.** With room X open, put the app in the background. Post in X from another phone and tap the push. No second screen opens, and X shows the new message. (A2)
- [ ] **Reconnect.** Turn Auto-Lock off, because locking now disconnects. With a DM open over a city room, wait an hour for the token to expire, or ask me to restart the backend. The DM keeps receiving, and going back to the city room shows it live. (A1)
- [ ] **Background.** In a room, press Home. Within 10 s, from another phone, post in that room and reply in a thread you follow: the push and the Activity entry arrive. Come back: the room, the chat-list previews and badges, and Activity are current without pulling to refresh. Repeat with a thread open and the phone locked. If iOS suspends the app before it can disconnect, the server notices about 45 s later, so re-run a failed attempt once before calling it a failure. (A4, A5, BE1)
- [ ] **Offline and back.** On the chat list, turn on airplane mode for 30 s while another phone posts and replies. After reconnecting, previews, badges and Activity catch up, with no duplicates. (A5)
- [ ] **Chat that can't open.** Open a room with WebSockets blocked (Proxyman or Charles) or with no connection. "Couldn't open this chat" with **Try again** appears after about 10 s, and the room loads once the connection is back. (A1, A2)
- [ ] **History kept.** In a busy room, scroll up two pages, turn on airplane mode for about 10 s, then turn it off. The older messages and your position stay, and nothing is duplicated. (A3)
- [ ] **Unread badges.** (A5)
  - Read a busy room while messages arrive, go back, close the app from the app switcher and relaunch: no badge.
  - Stay inside the room, swipe the app away from the app switcher and relaunch: no badge.
  - Say hey and go back: no stale badge.
- [ ] **Android picker.** Settings → Edit profile → pick a photo → come back. The app is live, with no error. (A4)

### Notifications (release blocker 3)
- [ ] **Android 13+, fresh install, new account.** No permission dialog on the sign-in or username screens. The system dialog appears **once**, when the chat list shows. Choose Allow, then send a DM from another phone while the app is in the background: a heads-up notification with sound. (C1)
- [ ] **Android, refused.** Same, but choose Don't allow, and the "Notifications are off" banner appears. Tap its button: the system dialog shows once more. Refuse again, tap the button again, and Settings opens. The dialog never comes back by itself after a relaunch, a logout and sign-in, or leaving a room. (C1)
- [ ] **Upgrade (Android 13+).** Install the new build over build 11 while signed in: the dialog appears once, on first launch. (C1)
- [ ] **Android 12 or older.** No dialog, notifications arrive, and there's no banner unless notifications are off in Settings. (C1)
- [ ] **iPhone, fresh install.** The alert appears when the chat list shows, not during sign-in. (C1)
- [ ] **iPhone, app closed.** Tap a DM notification, then a reply notification. Each opens the right room or thread. Repeat right after a reboot. (C2)
- [ ] **iPhone sound.** With the ringer on, DMs, replies and room messages play the default sound. (BE4)
- [ ] **iPhone badge.** With the app closed, receive two DMs and a reply: the icon shows the right count. Open the DMs and Activity: it goes down. Log out: it clears. City-room messages don't raise it. (C3, BE9)

### Sign-in, sign-out and accounts
- [ ] **Log out on Wi-Fi.** The intro appears within a second. A DM to that account from another phone produces no notification. (B2, BE3)
- [ ] **Log out in airplane mode.** The intro appears at once, and a relaunch stays signed out. Turn the network back on and wait about 10 s: a DM produces no notification. (B2)
- [ ] **Log out after an hour away.** Leave the app in the background for over an hour, open it and log out at once: no notifications afterwards. (B2, BE3)
- [ ] **Sign back in.** Log out and sign back in. Activity shows the right items and badge, and a new reply appears live once. Settings → Passkeys → "Sign in again" behaves the same. (B1)
- [ ] **Switch accounts.** Sign in as A, log out, sign in as B. Nothing of A's shows anywhere, and the username page has no preselected photo. (B1, F2)
- [ ] **Back after sign-in.** After each sign-in path (Google, Apple, passkey, new username), Android back on the chat list leaves the app and the iOS swipe does nothing. (B4)
- [ ] **Refresh while offline.** Leave the app in the background for over an hour, turn on airplane mode, open it, then turn airplane mode off: still signed in. (M2, unchanged behaviour)
- [ ] **Lost refresh responses.** iPhone, over a day: repeatedly open the app after more than an hour away and send it to the background within a second. It never signs itself out. (BE2)
- [ ] **Export and deletion.** Export my data to Files or Drive and to Mail: the file arrives complete. Delete the account: the sign-in screen shows no passkey button. (B3)
- [ ] **Ban and suspend.** (BE5)
  - Ban a test account (`POST /v1/admin/users/:id/ban`): the open app signs out with "Your account has been banned. Reason: …".
  - Unban it, sign in, then suspend it with a date (`…/suspend`): "Your account is suspended until … Reason: …".
  - Unban it afterwards.

### Passkeys on Android (release blocker 4)
- [ ] **Create.** Play internal-testing build: sign in with Google to an account without a passkey. Android offers to create one, and you land on Chats. Settings → Passkeys lists it. (H1, BE7)
- [ ] **Sign in.** Sign out, then "Sign in with Passkey" works on the Play build. On iOS, passkeys still work. (H1, BE7)
- [ ] **Errors.** Cancelling any sign-in shows no red box. Apple sign-in failures show "Apple sign-in didn't finish. Try again?", never exception text. If the automatic passkey offer fails, only "You can add a passkey later in Settings." appears. (E1)

### Moderation and Activity
- [ ] **Report from a thread.** In a thread, long-press someone else's reply: Report message and Block author appear. The report shows up in `GET /v1/admin/reports` with the reply text. (D1)
- [ ] **Block from a thread.** Block the author of a thread's first message from inside the thread. The thread stays open, and their replies disappear. (D1)
- [ ] **Block and unblock.** Block someone whose reply is in your Activity: their items and badge go at once. Unblock: they come back. (D2)
- [ ] **Removal.** Phone B posts a message in a city room, and phone A replies to it in a thread, so B gets an Activity item. With phone B on the chat list, remove B's message with `DELETE /v1/admin/messages/:id`. B's chat-list preview and the Activity item both update within about a second. (D2, BE6)
- [ ] **Only Activity item.** With exactly one item in Activity, tap it: the thread opens. (D3)
- [ ] **Back during loading.** Android, slow network: tap an Activity item and press back during the spinner. You stay on Activity, the item is still there, and nothing opens later. (D3)

### Compose, profile and look
- [ ] **Long message.** On a small phone with the keyboard up, paste about 3,000 characters. The box stops at 2,000 characters and 6 visible lines, send works, and the other phone receives exactly that text. (F1)
- [ ] **HEIC photo.** Android: pick a HEIC photo in onboarding and in Edit profile. It uploads. (F2)
- [ ] **Offline first launch.** A fresh install launched offline shows Outfit headings from the first frame. (F3)
- [ ] **Links.** iPhone: tap bleyachat.com/privacy in Notes. Safari opens, and the app doesn't flash. (F5, H2)
- [ ] **Status bar and offline strip.** iPhone in Dark Mode: the status bar is dark on every screen. Airplane mode: a readable red strip sits below the notch, and back buttons still work. (F6)

## 5. Before submitting to the stores

- [ ] **App Store Connect → App Privacy:** fill it in from the four-row table in `docs/store-privacy-answers.md`: Email Address, User ID, Photos or Videos and Other User Content, each linked to the user, not used for tracking, used for app functionality. Compare it with Xcode's privacy report for the release archive (F4).
- [ ] **Play Console → Policy and programs → App content:** confirm there's no Child safety standards declaration to complete. If there is one, tell me, and we use the minimal section below.
- [ ] **Android go-live:** `bundle exec fastlane android_promote_production version_code:<N that passed the checks>`, then review and roll out the draft in Play Console.
- [ ] **iOS:** submit the build that passed the device checks.

## If Play asks: minimal child-safety section

Use this only if Play Console asks for the Child safety standards declaration even under Communication. It would become Terms Section 5 (`/terms#child-safety`), renumbering the rest. It names no authority, and it promises no review times or photo checks.

> **5. Child safety**
>
> Bleya and Readyque DOO have **zero tolerance for child sexual abuse and exploitation (CSAE)**. You must not use Bleya to share, request, or link to child sexual abuse material; to groom or sexualise a child; to ask a child for sexual images, sexual contact, or a meeting; or to threaten or blackmail a child with intimate images.
>
> **How to report.** In the app, press and hold a message and choose **Report message**, open a profile and choose **Report user**, or open a room's details and choose **Report room**. If you think someone is under 15, choose **Under 15**. You can also block anyone. If a child is in immediate danger, contact your local police or emergency number.
>
> **What we do.** When we learn of CSAE on Bleya, we remove the content, ban the accounts involved, and act as the law requires.
>
> **Contact.** Questions about these standards: support@bleyachat.com.

Then fill in the declaration with that URL, and give your name and support@bleyachat.com as the contact.
