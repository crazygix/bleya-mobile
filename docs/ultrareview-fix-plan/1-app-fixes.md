# Mobile ultrareview fix plan — 1. App fixes

**Status:** **Implemented on October 2, 2026**, following [your decisions](2-your-checklist.md#1-your-decisions-october-1-2026).
- App: commits `40a6e6a`…`b7d2282`. `flutter analyze` is clean and 649 tests pass.
- Build: 1.0.0 (12), commit `a66c2ac`, tag `build/12`, is on TestFlight and Play internal testing.
- Website: H1 and H2 are committed and pushed but **not live yet**; see the checklist.
- Still open: what's left is in [the checklist](2-your-checklist.md#status-october-2-2026).

**Based on:** the ultrareview of the mobile app on September 30, 2026: 63 confirmed findings, which come down to 40 separate issues, 5 of them release blockers. Each fix lists the finding ids it closes.
**Last updated:** October 2, 2026

The plan has three parts:
1. **This document:** what changes in the app (and on the website, where the app depends on it), in the order I'll make the changes.
2. [2-your-checklist.md](2-your-checklist.md): what only you can do (decisions, console work, approvals) and the device checks once the fixes are in.
3. [3-backend-changes.md](3-backend-changes.md): what the backend needs to stay in step with the app, with contracts and deploy order.

## The five release blockers

| # | Problem | Fixed by |
|---|---|---|
| 1 | Chat screens stack: a thread opened from a push can sit over a DM, and a "Say hey" DM over a city room. When the top screen closes, the connection is left in the wrong room. The screen underneath stops receiving messages and can even send into another room. | A1–A3, BE1 |
| 2 | In the background the app stays in its chat, so the server holds back that user's pushes. When the user returns, nothing catches up. | A4, A5, BE1 |
| 3 | Android 13+ never shows the notification permission prompt. | C1 |
| 4 | Passkeys fail on every Android install from Google Play. | E1, H1, BE7, and your Play Console step |
| 5 | Google Play's Child Safety Standards policy (Social and Dating apps, and anonymous or random chat apps) needs published standards and a declaration. | H3: you list Bleya under Communication, which most likely takes it out of scope |

Also needed in the next tester build: **D3**. Tapping the only item in Activity can leave the app stuck behind a spinner.

## Order of work

Each step can be reviewed on its own. I'll ask before committing, pushing or deploying anything.

1. **You:** the decisions and the "before I start" items in [the checklist](2-your-checklist.md), including committing the four files you have open.
2. **Backend.** Every backend change works with build 11, so the backend ships first: BE1, BE4 and BE5, then BE2 and BE3, then BE6. Then BE7 in Railway. BE9 (the iOS badge) can go out at any point, because it only sends badge counts to app builds that ask for them.
3. **Website deploy:** H1 and H2, once BE7 is live and you've sent the Play signing key.
4. **App foundations:** the shared test fakes (the fake HTTP adapter from G1, `FakeSocketService`, the fake socket from A1), then B1.
5. **App, chats and background:** A1–A5, as one change set, because the socket API changes for all of them together.
6. **App, sessions and push:** B2–B4 and C1–C3, which share the push service and controller.
7. **App, moderation and errors:** D1–D3 and E1.
8. **App, compose, UI and platform:** F1–F10.
9. **Tests and tooling:** G1–G3 and the doc updates.
10. **Release build:** `bundle exec fastlane testing` (1.0.0+12), then the device checks.
11. **Store forms, then go-live.**

Where two items edit the same code, the later one builds on the earlier:
- `notification_provider.dart`: B1, then A5, then D2;
- `RoomsListController`: B1, then A5, then D2;
- the push service and controller: C1, C2 and B2 together;
- `chat_room_page.dart` and `thread_view_page.dart`: A2, then D1, then D3;
- `authorisation_page.dart` and `username_page.dart`: B4, E1, F2 and F6, each touching only its own lines.

---

## A. Chats, threads and the app in the background (release blockers 1 and 2)

The app has one socket, which can be in one room at a time, but chat screens stack. Today whichever screen joins last moves the socket. Nothing moves it back when that screen closes, and a delayed rejoin after a reconnect can move it to the wrong room. In the background, the socket stays in its room, so the server treats the user as present and holds back their pushes.

The fix: SocketService becomes the only owner of room state, and each chat or thread screen holds a *claim* on its room. Every message carries its room id, and the server refuses a mismatch. The app disconnects in the background and catches up when it comes back.

### A1. SocketService owns the room through claims — **L**
**Fixes:** COR-1, COR-2, COR-3, COR-9, API-5, REL-1, REL-3, REL-6, and the socket tests from QA-3.

**Changes** in `lib/services/socket_service.dart`:
- **Claims.** `_currentRoom`, `_desiredRoom`, `_activeThreadId` and `_desiredThreadId` become an ordered list of `RoomClaim`s, one per screen (a room, plus a thread for thread screens). The socket follows the newest claim that is still alive. Releasing a claim falls back to the one below it, and with no claims left it emits `leave_room`.
  - This replaces `joinRoom`, `leaveRoom`, `openThread`, `closeThread`, `onRoomJoinedConfirmed`, `_doJoinRoom` and `_emitOpenThreadIfNeeded`.
  - The new API is `claimRoom(room, {threadId})`, `activateClaim`, `releaseClaim` and `releaseRoom(roomId)`.
- **One sync step.** `_sync()` decides what to emit from the claims as they are at the moment it runs. It runs on every claim change, connect, `room_joined`, `NOT_IN_ROOM` and retry, and does nothing while disconnected, so no stale packets are queued. It replaces the 100 ms delayed rejoin that could move the socket back to an old room.
- **Confirmed joins.** The joined room is set only by `room_joined`, through an internal handler registered when the socket is created. `open_thread` and `close_thread` go out only after the claimed room is confirmed. That also works for a thread opened from Activity with no room screen underneath, and it removes the false "That reply belongs to a different chat." error.
- **Join failures.** `join_room` is sent with an acknowledgement. A refusal, or no `room_joined` within 10 s, publishes a `RoomJoinFailure` on a `joinFailures` stream, with the server's message, a timeout or "not connected". A failed room isn't retried until the user taps Retry, the socket reconnects or the claim changes. Acknowledgements for older or superseded joins are ignored.
- **Room-checked sends.**
  - `sendMessage(text, {required Room room, parentMessageId})` includes `roomId`. It refuses locally with `NOT_IN_ROOM`, sending nothing, while the confirmed room is a different one.
  - After a local or server `NOT_IN_ROOM`, if that room is the top claim, it waits up to 5 s for the rejoin and retries once. Concurrent sends share one rejoin.
  - The existing acknowledgement flow from M4 stays: the input clears at once, and the text is restored on failure.
- **Error events.** A `NOT_IN_ROOM` error event clears the confirmed room and runs `_sync()`, so only the top claim's room is rejoined. Screens lower in the stack never pull the socket.
- **The open chat.** `openChat` is derived from the claims and holds the visible room id and thread id. It replaces `currentOpenRoomIdProvider` and `currentOpenThreadIdProvider`, which drifted out of sync with the screen (part of COR-2). It is published in a microtask so listeners never run during build or dispose.
- **New screens.** `requestRoomSnapshot(room)` forces a fresh `room_joined` for a new screen on a room that is already joined; today that join is skipped and the screen hangs (COR-1). `retryJoin(room)` backs the Retry button.
- **Sign-out.** `setToken(null)` and `disconnect()` also clear claims, joins and timers.
- **Tests.** An optional socket factory (default `io.io`) and a fake socket in `test/fakes/fake_io_socket.dart`.

**Backend:** [BE1](3-backend-changes.md) adds the `roomId` check, the join acknowledgement and "last request wins". On today's backend the local checks and the 10 s deadline still protect the app.

**Tests** (fake socket plus fake time):
- a claim over a claim joins the top one, and releasing it rejoins the one below;
- two claims on the same room emit nothing extra;
- releasing the last claim emits `leave_room`;
- `open_thread` goes out only after `room_joined`;
- a reconnect with two claims joins only the top one, even 200 ms later;
- a `NOT_IN_ROOM` event rejoins only the top claim;
- a send for another room is refused locally, then retried once after the rejoin, and two concurrent sends share one join;
- join refusal and timeout;
- the M1 paths still work: server disconnect, then backoff and rejoin; `TOKEN_EXPIRED`, then refresh and rejoin; a ban calls `onFatalError` with no reconnect; `Server unavailable:` schedules a retry and never signs out; the connect timeout.

### A2. Screens hold claims — **S**
**Fixes:** COR-1, COR-2, REL-3, API-1 (the thread screen now leaves), and REL-6 (error state).

**Changes**
- `lib/utils/navigation.dart`: add `appRouteObserver`. `lib/main.dart`: add `navigatorObservers: [appRouteObserver]`.
- `ChatRoomPage` and `ThreadViewPage`:
  - claim in `initState`; thread screens claim the room and the thread;
  - re-activate the claim in `didPopNext`, which fires when the screen above starts closing;
  - release it in `didPop`, and again in `dispose`, which covers `removeRoute` and `pushNamedAndRemoveUntil`.
- `ChatRoomPage`:
  - stop writing `currentOpenRoomId`, calling `markRoomAsRead` and clearing the shared message list. The clearing emptied the list when a push opened a second screen for the same room;
  - call `controller.ensureLoaded()`;
  - when the join failed and nothing has loaded, show the shared `ErrorState` instead of the skeleton: "Couldn't open this chat", with the server's reason or "Check your connection and try again.", and a **Try again** button.
- `ThreadViewPage`: drop `joinRoom`, `openThread`, `closeThread`, the `currentOpenThreadId` writes and the dispose microtask.
- `lib/main.dart` `_handlePushNavigation` (your choice): if `openChat` already shows that room with no thread open, or that exact thread, don't open another screen. The open chat already shows the new message.
- `dashboard_page.dart`: drop the `currentOpenRoomId` reset on tab change, since the open chat is now derived.
- `chat_providers.dart` `leaveRoom()`: release the room after the HTTP leave succeeds, so a reconnect can't rejoin a room the user just left.

**Tests:** a new route test with `FakeSocketService`:
- push X, push X again, pop: the list is untouched and X is still claimed;
- push X, push D, pop: X is re-activated;
- X, then a profile, then `pushReplacement` to DM D, then pop: X is re-activated. This is the "Say hey" path, which `RouteObserver` doesn't report;
- a thread screen removed with `removeRoute` releases its claim in `dispose`;
- the error state appears, and Try again retries.

Update the thread page test.

### A3. Room and thread lists merge instead of reset — **M**
**Fixes:** REL-19, REL-6, COR-5 (threads), COR-2.

**Changes** in `lib/providers/chat_room_providers.dart`:
- `ChatRoomController`:
  - the constructor only registers listeners and no longer joins;
  - `room_joined` goes through a pure `mergeLatestPage()`. Where the new page overlaps what's loaded, older pages and the cursor stay; where there's a gap, the page replaces the list. The page's own window is authoritative, so removed and blocked messages drop out;
  - `new_message` skips ids already listed;
  - a join failure sets `joinError`, and `retryJoin()` clears it;
  - `NOT_IN_ROOM` events are ignored here, because SocketService handles them;
  - other errors show only while this room is the open chat;
  - `sendMessage` passes the room, and the retry now lives in SocketService. The deduplication of the matching `'error'` event stays.
- `ThreadController`:
  - registers its listeners before the first fetch, and merges replies that arrive during a fetch;
  - refetches when its room is joined again;
  - a failed refetch keeps what it has.

**Tests:**
- `mergeLatestPage` unit tests: overlap, gap, a removed message inside the window, ties on time;
- controller tests: duplicate ids, `joinError` and retry, no rejoin on a `NOT_IN_ROOM` event, errors only while the room is open;
- thread controller tests: a reply during the first fetch appears once; a refetch after `room_joined` merges; a failed refetch keeps the replies.

### A4. Leave the chat when the app goes to the background — **S**
**Fixes:** REL-4, API-1.

**Changes**
- `SocketService.setForeground(bool)`.
  - **Background:** fails any pending connect attempt (`_finishConnectAttempt`), cancels the retry and join timers, and calls `_socket?.disconnect()`. It keeps the claims, the listeners and `_wantsConnection`. It does **not** use `disconnect()` or `_stopReconnecting()`; those are for sign-out and drop every listener. Nothing reconnects while in the background. There is no grace timer, because iOS stops timers once it suspends the app.
  - **Foreground:** starts a new connect attempt if a screen wants the socket. An expired token goes through the existing refresh path. The claims are then rejoined and open threads reopened.
- `socketServiceProvider` (`auth_providers.dart`) registers an `AppLifecycleListener`, which starts from `WidgetsBinding.instance.lifecycleState`, treating a missing state as foreground.
  - Resumed means foreground; hidden, paused or detached mean background.
  - **Inactive is ignored**, so the app switcher, Face ID, permission prompts and share sheets don't disconnect.

**Backend:** [BE1](3-backend-changes.md) also stops a join that finishes *after* a disconnect from marking the user present. Without it, backgrounding right after opening a chat could keep that room's pushes held back.

**Tests:**
- background disconnects once, and nothing reconnects over two minutes of fake time;
- foreground reconnects, rejoins the top claim and reopens the thread;
- background while a connect is pending, then foreground within 25 s: a new connect attempt starts and the top claim is rejoined;
- a token refresh that finishes while in the background doesn't connect.

### A5. Catch up after a reconnect; keep the read position current — **M**
**Fixes:** COR-5, COR-6, API-2, and the catch-up part of REL-4.

**Changes**
- `SocketService.resyncRequests` fires:
  - once after each reconnect;
  - once per return to the foreground, as soon as that return's reconnect completes or fails. A failed reconnect still refreshes the lists over HTTP, which matters where WebSockets are blocked;
  - on the first connect of a session, if the chat list or Activity failed to load.
- `RoomsListController` (`chat_providers.dart`):
  - refreshes on each resync;
  - `refresh()` uses the server's unread counts, with 0 for the open room;
  - `room_summary_updated` events that arrive during a fetch are kept and applied after it;
  - summaries no newer than what's shown are ignored;
  - overlapping `refresh()` calls run once more instead of being dropped. D2 reuses this.
- `NotificationNotifier` gets `refresh({silent})`. A silent refresh keeps the list on screen, and overlapping calls run one after another. It runs on each resync, and D2 reuses it.
- **Read position:**
  - `markRoomAsRead` always sends `POST /rooms/:id/read`, even while the list is loading; only the local badge waits;
  - a new `roomReadSyncProvider`, kept alive by the dashboard, posts the read position whenever the open chat changes, for both the room that stopped being visible and the one that became visible;
  - it also posts when the app goes inactive, which covers closing the app from the iOS app switcher.
- Code that read `currentOpenRoomId` or `currentOpenThreadId` now reads `openChat`: `RoomsListController` and `notification_provider.dart`.

**Tests:**
- rooms list: refresh on resync, server counts, events kept during a fetch, stale summaries ignored, the POST while loading;
- resync: a failed cold-start load refreshes on the first connect; one return to the foreground causes one resync;
- read sync: X, then D, then X, then nothing posts in order; going inactive posts the open room's read position once;
- notifications: a silent refresh keeps the data on failure and keeps live arrivals.

**Done when** (blockers 1 and 2): all the "Chats, threads and background" checks in [the checklist](2-your-checklist.md#chats-threads-and-background-release-blockers-1-and-2) pass on an iPhone and an Android phone.

---

## B. Sign-out, sign-in and switching accounts

### B1. Session data follows sign-in and sign-out — **S**
**Fixes:** COR-4, REL-5, QA-1.

Today the session version changes only inside logout, while the chat list is still on screen. Activity and the chat list rebuild signed out and stay that way after the next sign-in in the same app run: Activity is empty, the badge stays at 0, and new replies don't appear live until a restart.

**Changes**
- `lib/providers/auth_providers.dart`: `sessionVersionProvider` becomes a Notifier that follows the signed-in user: the user id in the token, or nothing when signed out. It counts every sign-in, sign-out and account switch, but not token refreshes, so no code that writes the token has to remember to bump it. Add `sessionIdentityOf(token)`.
- `lib/utils/jwt_utils.dart`: add `userIdOf(token)`. `currentUserProvider` uses it too.
- `lib/services/auth_manager.dart`: remove the manual bump in `logout()`.
- `lib/providers/notification_provider.dart`:
  - the socket listener removes its handlers when disposed, and registers nothing if the session changed while it was connecting;
  - `refresh` and `loadMore` drop a page that arrives after the session changed.
- `lib/providers/chat_providers.dart`: `RoomsListController` checks `mounted` after each await, before adding listeners or setting state.
- `lib/services/socket_service.dart`: `onNewNotification` and `onNewNotificationEntity` return the handler they registered.

**Tests:** new `test/providers/session_providers_test.dart`:
- the version changes on sign-in and sign-out, not on a refresh;
- after sign-out and sign-in, Activity loads again and has exactly one live handler;
- a sign-out during the connect registers nothing;
- a late page is dropped.

Update `test/services/auth_manager_test.dart`.

**Done when:** after Log out and signing back in, Activity shows the right items and badge and a new reply appears live exactly once. Signing in as another account shows nothing from the first one.

### B2. Logout clears the phone first, then tidies up the server — **M**
**Fixes:** SEC-2, SEC-3, SEC-6, COR-8, TNS-5, API-7, REL-10, and the launch-notification replay from REL-5.

Logout currently does its network calls before clearing anything, which can take up to a minute on a bad network. Its push clean-up can fail quietly. A refresh that is still running can also store a login cookie after the cookie jar was cleared.

**Changes**
- `lib/services/auth_manager.dart`: `logout({bool accountDeleted = false})` does the local teardown first:
  1. cancels and waits for any running refresh (a `CancelToken` per refresh);
  2. reads the refresh cookie;
  3. disconnects the socket;
  4. clears the token, `auth_token` and the cookie jar;
  5. resets bootstrap and goes to the intro.

  Then it clears the Google session and the export files (B3), each step on its own. Last, without waiting, `_endRemoteSession(cookie)` posts `/auth/logout` with that cookie through a separate Dio client (no cookie jar, no auth interceptor, 5 s timeouts) and deletes the FCM token.
- `lib/providers/auth_providers.dart`:
  - add `sessionCleanupDioProvider`;
  - `logoutProvider` takes `accountDeleted`;
  - `bootstrapProvider` only logs out if a token is still set.
- `lib/services/push_messaging_service.dart`:
  - add `deleteTokenAfterSignOut()`: it saves a "deletion pending" flag in secure storage, calls `FirebaseMessaging.deleteToken()` with a 10 s timeout, and clears the flag on success;
  - add `retryPendingTokenDeletion()` and `clearPendingTokenDeletion()`;
  - `getToken()` waits for a deletion that is still running.
- `lib/controllers/push_notifications_controller.dart`:
  - retry a pending deletion while signed out: at start, on resume, and when the connection returns (`isOnlineProvider`);
  - clear the flag after a successful registration;
  - handle the notification that launched the app only once per app run, so it isn't replayed after the next sign-in.
- `lib/services/secure_cookie_storage.dart`: `_clearLeftoverSession` also deletes the "deletion pending" flag. iOS keeps Keychain items across a reinstall, so without this a fresh install would delete its brand-new FCM token.
- Remove the app's `/notifications/push/unregister` call and `UnregisterPushTokenUseCase`; the endpoint stays for build 11. `AuthRepository.logout()` goes away, because its steps move into the teardown, and the repository gains `forgetRegisteredPasskey()`.
- Forced sign-outs (a refresh answered with 401 or 403, a ban on the socket) and account deletion run the same teardown.

**Backend:** this works with today's backend. With [BE2 and BE3](3-backend-changes.md), logout also ends the previous refresh token and switches off the account's push token on the server.

**Tests:** rewrite `test/services/auth_manager_test.dart` with in-memory secure storage and fake HTTP adapters. It checks that:
- the session is cleared before the network calls finish;
- the captured cookie is the one sent;
- a running refresh can't store its cookie;
- the FCM token is deleted even if `/auth/logout` fails;
- a second logout does nothing.

Add `test/services/push_messaging_service_test.dart`, and update the interceptor and push controller tests.

**Done when:** logging out on Wi-Fi or in airplane mode shows the intro within a second, a relaunch stays signed out, and the phone gets no notifications for that account afterwards.

### B3. Export and account deletion leave nothing behind — **S**
**Fixes:** SEC-8, TNS-9.

**Changes**
- New `lib/services/data_export_file.dart` with `write`, `delete` and `deleteAll`. `deleteAll` also removes Android's copy in `cache/share_plus`.
- `lib/pages/settings_page.dart`: the export deletes its file once the share sheet closes. Account deletion calls `logout(accountDeleted: true)`.
- Logout always removes the export files. With `accountDeleted` it also clears the "has a passkey" flag. A plain logout keeps the flag, so a returning user can still sign in with their passkey.

**Tests:** `test/services/data_export_file_test.dart`, plus auth manager cases for the passkey flag and the export files.

**Done when:** the export still arrives complete, no export file is left on the phone afterwards, and after deleting the account the sign-in screen offers no passkey sign-in.

### B4. After sign-in, the chat list is the only screen — **XS**
**Fixes:** COR-7, REL-8.

**Changes**
- `lib/utils/navigation.dart`: add `showHomeAsOnlyRoute(navigator)`, which calls `pushNamedAndRemoveUntil('/home', (_) => false)`. Use it at the four sign-in and onboarding completions in `authorisation_page.dart` and `username_page.dart`.
- `username_page.dart`: wrap the page in `PopScope(canPop: false)`, so system back runs the same logout as the page's back button.

**Tests:** `test/utils/navigation_test.dart`.

**Done when:** after every sign-in path, Android back on the chat list leaves the app and the iOS edge swipe does nothing.

---

## C. Push notifications

### C1. Ask for notification permission once — **S** (release blocker 3)
**Fixes:** TNS-1, REL-2.

On Android, a permission the app never asked for reads as "denied", so the app never shows the prompt.

**Changes**
- `lib/services/push_messaging_service.dart`: remember in secure storage that the app has asked (`hasRequestedPermission`, `markPermissionRequested`). This flag belongs to the install, so logout doesn't clear it.
- `lib/controllers/push_notifications_controller.dart`:
  - registration never prompts;
  - the new `requestPermissionIfUndecided()` (single-flight) asks when iOS says "not determined", or Android says "denied" and the app hasn't asked yet;
  - the "Notifications are off" banner appears only after a refusal;
  - the permission state is read again at sign-in and on resume.
- The banner's button on Android (your choice): it first uses Android's one extra permission dialog. If the answer comes back "denied" straight away, or the user refuses again, it opens Settings. A second flag in secure storage records that the extra dialog was used.
- `lib/pages/dashboard_page.dart`: call it on the chat list's first frame, on both platforms.
- `README.md`: update the push notifications section.

**Tests:**
- controller cases: Android never asked, refused, and turned on in Settings then resumed; iOS "not determined" and denied; two calls at once; a request that throws;
- the Android banner asks once more, then opens Settings;
- `push_messaging_service_test.dart`;
- one dashboard test.

**Done when:** on a fresh Android 13+ install the system dialog appears once, when the chat list first shows. Refusing shows the banner. Its button shows the system dialog one more time, then opens Settings. iOS asks at the same point.

### C2. Opening a notification doesn't wait for push registration — **S**
**Fixes:** REL-11.

**Changes** in `push_messaging_service.dart` and `push_notifications_controller.dart`:
- `getToken()` turns iOS's "APNs token not set" into `ApnsTokenNotReadyException`.
- Registration never throws. On that exception it retries on a short timer (2 to 32 s, 5 tries), which is cancelled at sign-out.
- Handling the tap that launched the app, registration and the permission refresh run side by side.

**Tests:** fake-time cases for the retry and its cancellation. A cold-start tap still opens its chat when APNs isn't ready or registration hangs.

**Done when:** on a killed iPhone, tapping a DM or reply notification opens that room or thread every time, including right after a reboot.

### C3. iOS app-icon badge — **M** (your request)
**Not a review finding:** you asked for it for launch.

**Changes**
- `ios/Runner/AppDelegate.swift`: a small method channel, `bleya/badge`, with `setBadgeCount(n)`. It uses `UNUserNotificationCenter.setBadgeCount` (iOS 16+) and falls back to `applicationIconBadgeNumber`. No new dependency.
- New `lib/services/app_badge_service.dart` plus a provider that keeps the badge equal to what the app shows. The count is unread Activity items plus DMs with unread messages; city rooms don't count, so busy rooms don't inflate it. It updates when either number changes and on resume, and goes to 0 at sign-out.
- `push_notifications_controller.dart`: register the push token with `badge: true`, so the server starts sending badge counts to this build (BE9).
- Android launchers show their own notification dots, so there are no Android changes.

**Backend:** [BE9](3-backend-changes.md) sends the same count in each push, for builds that registered with `badge: true`.

**Tests:** the badge provider (the count from Activity and DMs, 0 at sign-out, no call on Android) and the method channel call.

**Done when:** with the app closed, a DM sets the icon badge to the right number, reading the DM and Activity brings it down, and logging out clears it.

The iPhone notification sound is a backend change, [BE4](3-backend-changes.md).

---

## D. Moderation and Activity

### D1. Report and block from the thread screen — **S**
**Fixes:** TNS-3.

**Changes**
- Move `ChatRoomPage._showMessageActions` into `showMessageActions()` in `lib/widgets/report_actions.dart`. The room and `ThreadViewPage` both use it. In the thread, it covers the first message and replies by other people.
- Blocking the author of the thread's first message leaves the thread open (your choice). The first message stays until you leave, and their replies disappear as they do in the room. If the thread is opened again later, it shows "This message is no longer available.", because the server no longer returns it.

**Tests:** thread page widget tests for the sheet, the report request and blocking: the thread stays open and the blocked author's replies are hidden.

**Done when:** long-pressing someone else's reply in a thread offers Report message and Block author, and the report reaches the admin queue with the reply's text.

### D2. Activity and the chat list follow blocks, unblocks and removals — **M**
**Fixes:** TNS-4, API-9.

**Changes**
- New `lib/providers/block_providers.dart`: `recordBlockChange(ref, userId, blocked:)`, called by every block and unblock path. There are four in `user_details_page.dart`, plus the message sheet.
- `lib/providers/notification_provider.dart`:
  - `refresh({silent})` (added in A5) also runs after blocks and unblocks;
  - add `applySenderBlockChange` and `removeForMessage`;
  - ignore new notifications from blocked senders;
  - listen for `message_removed`, and remove that handler together with the others.
- `lib/services/socket_service.dart`: add `MessageRemovedEventData` and its parser. The author and time are optional.
- `lib/providers/chat_providers.dart`: `RoomsListController` registers its listeners once. When a removed message was a room's preview, it refreshes the list after 500 ms.

**Backend:** needs [BE6](3-backend-changes.md) for removals made while the user isn't in that room. Blocks work without it.

**Tests:** notification provider and rooms list tests, using the shared `FakeSocketService` moved in step 4.

**Done when:**
- blocking someone removes their Activity items and lowers the badge at once, and unblocking brings them back;
- a moderator removal updates the chat-list preview and Activity within about a second.

### D3. Opening an item in Activity — **M** (needed in the next tester build)
**Fixes:** REL-7.

Today the item is dismissed before its thread loads, and the loading spinner is tied to the item's own row. If it was the only item, the row disappears, the spinner never closes and the thread never opens, and on iOS nothing can dismiss it. On Android, pressing back during the spinner later closes the chat list instead.

**Changes**
- `lib/platform/app_dialog.dart`: add `AppDialog.open()`. It returns a handle that closes only its own dialog, and reports whether back has already dismissed it.
- `lib/pages/notifications_page.dart`:
  - open items from the page's own context, so the loader no longer depends on the row;
  - push the thread first, then dismiss the item;
  - if back dismissed the spinner, do nothing;
  - a 404 removes the item with "This message is no longer available.";
  - other errors show the friendly `AppError` message;
  - `markAllAsRead` in `dispose` moves into a microtask.
- `lib/pages/thread_view_page.dart`: the thread's error state shows "This message is no longer available." for a 404, the `AppError` message otherwise, and never raw error text.

**Tests:** `test/platform/app_dialog_test.dart` and `test/pages/notifications_page_test.dart`. Cases: the only item, back during loading, a screen pushed over the spinner, 404, network error.

**Done when:** tapping the only Activity item opens its thread. Pressing back during the spinner on Android keeps you on Activity with the item still there, and nothing opens later.

---

## E. Sign-in errors and passkeys

### E1. No raw error text in sign-in and passkeys — **S** (app side of release blocker 4)
**Fixes:** QA-4, and the app side of SEC-1.

**Changes**
- New `lib/utils/auth_error_messages.dart`: `authErrorMessage(error, fallback:)` turns any Google, Apple, passkey or platform error into fixed copy.
  - A cancel shows nothing.
  - An `AppError` shows its user message.
  - Anything else gets the caller's fallback, never `toString()`.
- Copy:
  - "Google sign-in didn't finish. Try again?" (Google's existing fallback);
  - "Apple sign-in didn't finish. Try again?";
  - "Passkey sign-in didn't finish. Try again?";
  - "Google sign-in isn't available right now. Try another way to sign in.";
  - "Passkeys aren't available right now. Try again later."

  The other passkey messages stay as they are.
- `lib/controllers/auth_controller.dart`: use it in place of `_resolveErrorMessage`, whose `toString()` fallback is the root cause. Debug builds still log the raw error.
- `lib/services/passkey_auth_service.dart`: give the Android errors the passkeys plugin leaves raw proper types. Android's "app not trusted for this domain" error becomes the same type iOS uses, so it also hides the passkey button.
- The automatic passkey offer after sign-in (`passkey_onboarding.dart`, `authorisation_page.dart`, `username_page.dart`), as you chose:
  - when it fails, it shows the neutral toast "You can add a passkey later in Settings.";
  - when the user cancels, it shows nothing;
  - it never shows error text.

  Settings → Passkeys shows the specific reason.
- `lib/pages/passkeys_page.dart`: use the same function instead of its own table.

**Tests:**
- `test/utils/auth_error_messages_test.dart`: a table test, plus a guard that no output contains "Exception";
- updated controller and onboarding tests.

**Done when:** cancelling any sign-in shows nothing and failures show friendly copy. An Android build whose key isn't trusted for passkeys signs in and shows only "You can add a passkey later in Settings."

The rest of blocker 4 is configuration: H1 (assetlinks.json), [BE7](3-backend-changes.md) (`PASSKEY_EXPECTED_ORIGINS`), and your Play Console step.

---

## F. Compose, uploads, UI and platform settings

### F1. Message box: bounded height and the 2,000-character limit — **S**
**Fixes:** REL-14, API-8.

**Changes**, all in the shared `lib/widgets/message_input_field.dart`, so the room and thread pages don't change:
- The box grows to 6 lines, or a quarter of the screen height if that's smaller, then scrolls inside. The send button stays visible.
- The server limit is 2,000 UTF-16 units. A new `Utf16LengthLimitingTextInputFormatter` enforces it, cutting only between whole characters and leaving text the keyboard is still composing alone.
- No character counter (your choice).
- Only a restored draft can go over the limit. If it does, tapping send shows "Messages can be up to 2,000 characters." instead of sending.

**Tests:** formatter tests (a paste across the limit, an emoji at the edge, text still being composed); widget tests with the keyboard up (no overflow, send reachable, an over-limit draft shows the message).

**Done when:** pasting about 3,000 characters on a small phone with the keyboard up stops at 2,000 characters and 6 visible lines, send works, and the other phone receives exactly the text shown.

### F2. Profile photo upload and the onboarding photo — **S**
**Fixes:** API-3, SEC-7.

**Changes**
- `lib/data/repositories/user_repository_impl.dart`: upload the photo as `profile.jpg` with type `image/jpeg`. The picker already re-encodes to JPEG, and the server checks the real bytes.
- `lib/controllers/username_controller.dart`:
  - the chosen photo can be cleared, and `resetTransientUiState` clears it;
  - a photo the server refuses (400) is dropped, so Continue works without one;
  - network and server errors keep it for a retry.
- `lib/providers/controller_providers.dart`: `usernameControllerProvider` becomes `autoDispose`, so the next account starts clean.
- `lib/pages/edit_profile_page.dart`: a refused photo is dropped, so the bio can still be saved.

**Tests:** a repository test that a `.heic` name is sent as `profile.jpg` with type `image/jpeg`, and username controller tests for clearing, the reset and a refused photo.

**Done when:** a HEIC photo picked on Android uploads in onboarding and in Edit profile, and a second sign-up in the same app run starts with no photo.

### F3. Bundle the heading font — **S**
**Fixes:** TNS-6, QA-2, REL-15.

**Changes**
- Add `assets/google_fonts/Outfit-SemiBold.ttf`, `Outfit-Bold.ttf` and `Outfit-ExtraBold.ttf`, the three weights in use, plus `OFL.txt`, and declare them in `pubspec.yaml`. Download each file from Google Fonts and check its SHA-256 against the file the app downloads today.
- `lib/main.dart`: set `GoogleFonts.config.allowRuntimeFetching = false` and register the font licence.
- Move the two inline `GoogleFonts.outfit` styles in `intro_page.dart` into `UiTokens` and `BleyaTheme` (`heroTagline`, `featureTitle`).

**Tests:** `test/constants/outfit_fonts_test.dart`: every Outfit style loads with runtime fetching off, and the licence ships.

**Done when:** a fresh install launched offline shows Outfit headings from the first frame and never contacts fonts.gstatic.com.

### F4. The iOS privacy manifest matches the App Store answers — **XS**
**Fixes:** TNS-7.

**Changes**
- `ios/Runner/PrivacyInfo.xcprivacy` declares exactly Email Address, User ID, Photos or Videos and Other User Content. Each is linked to the user, not used for tracking, and used for app functionality.
  - Remove the invalid "Messages" type and Coarse Location.
  - The accessed-API reasons stay as they are.
- `docs/store-privacy-answers.md`: note that the manifest mirrors the App Store table.

**Tests:** `test/config/platform_config_test.dart` pins the declared types, and `plutil -lint` passes.

**Done when:** Xcode's privacy report for the archive lists those four types and nothing else.

### F5. Stop opening the app for bleyachat.com links — **XS**
**Fixes:** SEC-5, TNS-10.

**Changes**
- `ios/Runner/Runner.entitlements`: remove `applinks:bleyachat.com` and keep `webcredentials:bleyachat.com`, which passkeys need.
- Turn off Flutter deep linking:
  - `ios/Runner/Info.plist`: `FlutterDeepLinkingEnabled = false`;
  - `android/app/src/main/AndroidManifest.xml`: `flutter_deeplinking_enabled = false` on `MainActivity`.
- `lib/platform/app_browser.dart`: update its comment.
- On the website, H2 removes `applinks` from the apple-app-site-association file.

**Tests:** extend `platform_config_test.dart` to check the entitlement, the Info.plist flag and the manifest flag.

**Done when:** tapping bleyachat.com/privacy in Notes opens Safari without the app flashing, and passkeys and Google sign-in still work on iOS.

### F6. Status bar and offline banner — **S**
**Fixes:** REL-18, REL-17.

**Changes**
- New `lib/widgets/app_shell.dart`, used by `MaterialApp.builder`:
  - one app-wide dark status bar style, which pages can still override;
  - the offline banner becomes a proper `Material` strip below the notch, and the app moves down while it shows;
  - the widget tree stays stable, so open screens keep their state.
- `BleyaTheme.systemOverlayStyle` replaces the two copies in the sign-in and username pages. `ConnectivityBanner` goes away.

**Tests:** `test/widgets/app_shell_test.dart`:
- the strip sits below a 47 pt inset, and its text isn't underlined;
- a page keeps its state when connectivity changes;
- the status bar style is right.

**Done when:** in iOS Dark Mode, the clock and battery are dark on every screen. In airplane mode, a readable red strip sits below the notch and back buttons still work.

### F7. Cheaper background — **S**
**Fixes:** REL-13.

**Changes**
- `lib/widgets/liquid_glass_background.dart`: the three full-screen blurs become one painter that draws radial gradients with the same colours, positions and falloff.
- `lib/pages/settings_page.dart`: remove the second, nested background.
- `rules/theme-and-brand-rules.md`: no unclipped `BackdropFilter`.

**Tests:** `test/widgets/liquid_glass_background_test.dart`: no BackdropFilter, and it fills its parent.

**Done when:** side-by-side screenshots match today's look (you sign off), and scrolling is smoother on a mid-range Android phone in a profile build.

### F8. Avatars decode near their display size — **XS**
**Fixes:** REL-16.

**Changes:** `ProfileAvatar` and `NotificationTile` load photos through `ResizeImage` at twice the display size times the screen's pixel ratio. `NotificationTile` keeps its check for invalid URLs and its fallback (M11). Caching photos between launches is left for after launch.

**Tests:** `test/widgets/profile_avatar_test.dart`, plus a check that `NotificationTile` still shows its fallback for an invalid URL.

**Done when:** DevTools shows avatars decoded at no more than twice their display size, and they look as sharp as before.

### F9. Date labels count calendar days — **XS**
**Fixes:** COR-10.

**Changes:** `lib/utils/time_formatter.dart` gets `calendarDaysBetween()`, used by both formatters. This also fixes gaps of 28 or 29 days showing "0mo".

**Tests:** new `test/utils/time_formatter_test.dart`, including the spring clock change.

### F10. Debug logs stop printing request bodies — **XS**
**Fixes:** SEC-9.

**Changes:** `dioProvider` in `auth_providers.dart` uses `LogInterceptor(requestBody: false)`. Only debug builds log at all.

**Tests:** `test/providers/dio_logging_test.dart` checks that sign-in secrets never appear in the log.

---

## G. Tests and release tooling

### G1. Tests for every endpoint the app calls — **M**
**Fixes:** QA-3 (data layer; the socket tests are in A1).

**Changes**
- `test/fakes/fake_http_adapter.dart`: the shared fake Dio adapter, moved out of `auth_interceptor_test.dart`.
- `test/fixtures/api_fixtures.dart`: one fixture per backend response, copied from the backend's serializers at the commit deployed in step 2. Each fixture names its source, and nulls and empty strings are kept exactly as the backend sends them.
- DTO tests for all ten DTOs.
- Repository tests for every HTTP repository call (44 endpoints). Each checks the request (method, path, query, body), the parsed result and one mapped error. That's about 85 new tests. `LocationRepositoryImpl` has no HTTP, so it's skipped.
- `rules/architecture-rules.md` and `rules/api-contract-rules.md`: one repository test per endpoint, and when a backend response changes, its fixture changes in the same change.

**Done when:** `flutter test` and `flutter analyze` are clean with the new tests.

### G2. Release lanes — **M**
**Fixes:** QA-5, QA-6.

**Changes** in `fastlane/Fastfile`:
- Every lane that builds first requires a clean git tree, then runs the quality checks (`release_preflight!`). `testing` checks the tree once and its sub-lanes skip the check, because the iOS build can rewrite tracked files before the Android half runs.
- `ios_testflight` checks App Store Connect access first, so the agreement hint always shows.
- `testing` writes the build number to `pubspec.yaml` once, after both uploads, and never lowers it. It then prints the `git commit` command and never commits itself. A rerun reuses the iOS build only if no code was committed since that upload.
- Android checks that Play accepts the build number before building. Each lane tags the build locally as `build/N`.
- Android go-live becomes `android_promote_production version_code:N`. It promotes the exact internal build that passed the device checks to a production draft instead of rebuilding.
- Track `ios/Podfile.lock` (add `!ios/Podfile.lock` to `.gitignore`), so a clean-tree build pins native pods.

Update `docs/release.md` and `fastlane/.env.example` to match.

**Done when:** a dirty tree stops a build before anything runs, and the promote lane creates a production draft without uploading a new bundle.

### G3. Remove the Xcode Cloud script — **XS**
**Fixes:** QA-7.

**Changes:** delete `ios/ci_scripts/ci_post_clone.sh` and the empty `.xcodecloud/` folder. Add a line to `docs/release.md` saying releases are built locally with fastlane.

---

## H. Website and Google Play listing

H1 and H2 go out in one website deploy, as soon as BE7 is live.

### H1. assetlinks.json trusts Play's signing key — **XS** (release blocker 4)
**Fixes:** SEC-1, together with E1 and BE7.

**Changes** in `public/.well-known/assetlinks.json` (website repo):
- The `com.bleyachat` entry lists Play's app-signing key and the upload key.
- The local debug key moves out of that entry and stays only in `com.bleyachat.dev`.
- The `handle_all_urls` relation can go too, since the app no longer handles links (F5). `get_login_creds` stays.

This needs the Play app-signing SHA-256 from you. Deploy it after BE7 is live in Railway, so Android can't create passkeys the server would then refuse.

**Done when:** Google's Digital Asset Links check reports "linked" for the Play key, and a Play-installed build can create and use a passkey. Build 11 benefits too.

### H2. apple-app-site-association drops applinks — **XS**
**Fixes:** SEC-5, TNS-10, together with F5.

**Changes:** remove the `applinks` block from `public/.well-known/apple-app-site-association` and keep `webcredentials`.

### H3. Child safety on Google Play — **XS** (release blocker 5)
**Fixes:** TNS-2.

Your choice: list Bleya under **Communication** in Play Console, like most chat apps (WhatsApp, Telegram, Discord).
- Google's Child Safety Standards policy covers apps in the Social and Dating categories, and anonymous or random chat apps.
- Bleya shows usernames and profiles, and doesn't match strangers at random, so the policy most likely doesn't apply. That means no Terms section, no declaration and no reporting procedure.
- Google decides the scope. If Play Console still asks for the Child safety standards declaration under App content, we add the short section in [the checklist's appendix](2-your-checklist.md#if-play-asks-minimal-child-safety-section) and fill in the declaration then.

**Done when:** Bleya is listed under Communication, and Play Console doesn't ask for the declaration.

---

## Not in this plan

- **REL-12** (a cold start waits for the socket before loading the chat list): after launch. Once A5 refreshes after reconnects and recovers a failed first load, the list can load without waiting for the socket.
- **Avatar caching between launches** (the rest of REL-16): after launch, with small server-side thumbnails.
- **Child-safety extras:** a "Child safety" report reason and an alert for such reports, after launch if you want them.
- **Profile-photo checks** keep their current behaviour when the automatic check can't run (your choice).
- **Character counter** in the message box: none, by your choice (F1).
- **Activity items that quote a thread whose author you blocked:** a backend change after launch; see the optional items in [3-backend-changes.md](3-backend-changes.md).
- TNS-8 (stating the minimum age in the app) was refuted in the review: it's covered by your passive-consent decision.

**Small follow-ups found during implementation (after launch):**
- **Missed message on reopen.** A chat screen that already shows messages can miss one live message in a rare case: another room is opened and closed before it finishes joining. A reply in that window can also leave its parent's reply count one too low. Reopening the chat fixes both.
- **Badge counts.** The iOS badge is counted in chunks of 100 recipients. Recipients with very many DMs could still make one chunk time out, and then only that chunk's badges are missing.
- **iOS launch screen.** It's still Flutter's placeholder: a polish item, not a store blocker.
