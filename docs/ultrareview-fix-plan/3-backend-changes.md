# Mobile ultrareview fix plan — 3. Backend changes

**Status:** Plan. Nothing has changed yet.
**Last updated:** October 1, 2026

This lists what the backend (`bleya/backend`, live at api.bleyachat.com, commit 63789b3) needs so it stays in step with the app fixes in [1-app-fixes.md](1-app-fixes.md). Your own steps (deploys, Railway, consoles) are in [2-your-checklist.md](2-your-checklist.md).

**Every change works with the current tester build 1.0.0+11**, and the new app also works with today's backend, so the backend ships first. No feature flags change.

## Summary

| ID | Change | For (findings) | App side | Effort |
|---|---|---|---|---|
| BE1 | Socket rooms: room-checked sends, acknowledged joins, last request wins | COR-3, COR-9, API-1, API-5, REL-1, REL-4, REL-6 | A1–A4 | S |
| BE2 | The previous refresh token stays valid until its successor is used | SEC-4, API-4, SEC-6 | none needed | M |
| BE3 | `/auth/logout` also switches off the account's push token | SEC-2, COR-8, TNS-5, API-7, REL-10 | B2 | S |
| BE4 | iPhone notifications play a sound | REL-9 | none | XS |
| BE5 | Ban and suspension text on the socket matches sign-in | API-6 | none | XS |
| BE6 | `message_removed` also reaches chat lists and Activity | TNS-4, API-9 | D2 | S |
| BE7 | Passkey origins for Play installs (Railway setting, plus an optional startup check) | SEC-1 | E1, H1 | XS |
| BE9 | iOS app-icon badge count in pushes, for app builds that ask for it | your request | C3 | M |

## Deploy order

1. **BE1, BE4, BE5**: small and independent.
2. **BE2, BE3**: authentication.
3. **BE6**: moderation events.
4. **BE7**: the Railway variable, **before** the website's assetlinks.json goes live (H1).
5. **BE9**: any time. It only sends badge counts to app builds that register with `badge: true`, so build 11 is unaffected.

All of these go out before the new app build reaches testers. I run each test file on its own (`npm run test:isolated`) before asking you to deploy. After each deploy, the build-11 smoke test in [the checklist](2-your-checklist.md#3-while-i-work) confirms nothing changed for testers.

---

### BE1. Socket rooms: room-checked sends, acknowledged joins, last request wins — **S**
**App side:** A1–A4.

The app can now say which room a message is for, and wants to know when a join fails. While planning, I also confirmed a server bug in `server/socket.ts`. A `join_room` or `open_thread` that finishes *after* its socket disconnected still records the user as present in that room. That entry stays until the server restarts (or until the user holds more than five connection entries at once), and meanwhile the user gets no pushes for that room. Disconnecting in the background (A4) would make this routine, so it's fixed here.

**Contract**
- `send_message {text, roomId?, parentMessageId?}`:
  - `roomId` is optional and validated.
  - If it differs from the socket's joined room, or the socket has no room, the server acks `{ok: false, error: {code: 'NOT_IN_ROOM', message: 'Not in a room. Reopen the chat and try again.'}}`. It also sends the usual `'error'` event, and stores, broadcasts and pushes nothing.
  - Without `roomId`, behaviour is unchanged.
- `join_room {roomId}` takes an optional acknowledgement:
  - on success: `room_joined` (unchanged), then `{ok: true}`;
  - on failure: `{ok: false, error: {code, message}}` and **no** `'error'` event;
  - without an acknowledgement, failures go to the `'error'` event as today.
- **Last request wins, per socket.**
  - A `join_room` that is overtaken while it loads changes no socket room, presence or `room_joined`. Its acknowledgement is `{ok: false, superseded: true}`. A later `join_room`, a `leave_room` or a disconnect overtakes it. The room-membership write inside `buildRoomJoinView` may already have happened by then; checking the counter just before that write narrows the gap.
  - An `open_thread` overtaken by a `close_thread`, `join_room`, `leave_room` or disconnect is dropped silently.
- The `'error'` event that accompanies a failed `send_message` stays until build 11 is gone.

**Changes** in `server/socket.ts`:
- `parseSendMessagePayload`: read and validate an optional `roomId`.
- `send_message`: after the existing no-room check, fail with `NOT_IN_ROOM` when `payload.roomId` differs from the room captured on arrival, and log `socket.send_message.room_mismatch`.
- Per-socket counters for joins and threads.
  - `join_room` bumps both at the start. After `buildRoomJoinView`, it stops if its counter moved or `socket.connected` is false. Optionally it also checks just before the membership write in `buildRoomJoinView`.
  - `open_thread` does the same after its lookup.
  - `leave_room` bumps both **before** its `if (!user.roomId) return`; otherwise a first join followed by a quick leave still writes presence.
  - `close_thread` bumps the thread counter before its rate-limit check, and the `disconnect` handler bumps both.
- `join_room` passes success and failure to the acknowledgement when one is given.

**Tests:** new `tests/integration/socketRooms.test.ts`. First move the file-local helpers in `socketPush.test.ts` (`waitFor`, `connectSocket`, `emitAndWait`) into `tests/helpers/` so both files share them. Cases:
- a send for another room is refused and stores nothing; a matching `roomId` is stored; no `roomId` is stored in the joined room;
- a join with an acknowledgement is refused with no `'error'` event; without one, the `'error'` event still comes;
- join X then Y back to back: only `room_joined(Y)`, X's acknowledgement is `{ok: false, superseded: true}`, and a send lands in Y;
- join then leave immediately: no presence, so pushes for X still arrive;
- join then disconnect before `room_joined`: pushes for X still arrive;
- open then close a thread immediately: replies still create the user's notification.

`realtime.test.ts` and `socketPush.test.ts` pass unchanged.

**Compatibility**
- **Build 11 on the new backend:** it sends no `roomId` and no join acknowledgement, so it behaves as before. The one difference is that overtaken joins and thread opens are dropped, which also removes its false "That reply belongs to a different chat." error.
- **New app on today's backend:** `roomId` is ignored, but the app's own check still prevents sends into the wrong room. With no acknowledgement, the app's 10 s join deadline applies.

### BE2. The previous refresh token stays valid until its successor is used — **M**
**App side:** none required. Build 11 benefits too.

Each `/auth/refresh` replaces the user's single refresh token. If the response carrying the new cookie never reaches the phone, the phone keeps a token the server no longer accepts, and its next refresh signs the user out. That happens after a timeout, a switch between Wi-Fi and mobile data, or iOS suspending the app mid-request. A 60-second grace period would not cover the iOS case, where the retry only comes at the next resume.

**Contract** (`POST /v1/auth/refresh`, request unchanged):

| Cookie presented | Response |
|---|---|
| Current token | `200 {token}` plus `Set-Cookie` with a new token (unchanged) |
| Previous token, within 30 s of its successor being issued | `200 {token}`, **no** `Set-Cookie`. This handles two refreshes sent at once. |
| Previous token, more than 30 s after its successor was issued, the successor not yet used, within 7 days of the first rotation | `200 {token}` plus `Set-Cookie` with a new token |
| Anything else | `401`, or `403 USER_BLOCKED` with the reason, and the cookie cleared (unchanged) |

`POST /v1/auth/logout` accepts the current cookie or an unexpired previous one, and ends both. A new sign-in, a ban, a suspension and account deletion also end both.

**Changes**
- `models/User.ts`: add `refreshTokenIssuedAt`, `previousRefreshTokenHash` and `previousRefreshTokenExpiresAt`, all `select: false`. Add sparse indexes on `refreshTokenHash` and `previousRefreshTokenHash`. `refreshTokenHash` has no index today, so every refresh scans the users. Mongoose builds the indexes at startup, so no migration is needed.
- `config/index.ts`: constants `refreshTokenReuseWindowMs = 30_000` and `previousRefreshTokenTtlMs` = 7 days.
- `repositories/userRepository.ts`:
  - `rotateRefreshToken` replaces `findOneAndUpdateByRefreshToken`, and keeps the old hash as the previous one;
  - add `reissueFromPreviousRefreshToken`, which matches only when the successor was issued more than 30 s ago;
  - add `findByRecentPreviousRefreshToken`, which matches when the successor was issued within the last 30 s;
  - `clearRefreshToken` matches the current or an unexpired previous hash, and clears all five fields.
- `services/authService.ts`:
  - `refreshAccessToken` tries, in order:
    1. rotate the current token;
    2. reissue from the previous token, but only when its successor was issued more than 30 s ago. The reissue sets a new current token and keeps the previous hash with its 7-day expiry, so even a second lost response still recovers;
    3. within those 30 s, the lookup that returns only an access token, so `RefreshResult.refreshToken` becomes optional;
    4. the existing 403 and 401 paths.
  - Every success path still runs the ban and suspension check.
  - `issueSessionForUser` clears the previous-token fields.
- `routes/auth.ts`: `/refresh` sets the cookie only when a new refresh token was issued.
- `services/moderationService.ts`: `applyEnforcement` also clears the three new fields.

**Tests**
- `tests/integration/auth.test.ts`:
  - reissue after the 30 s window;
  - no cookie within 30 s;
  - two refreshes at once;
  - the previous token expires after 7 days;
  - logout with the previous token;
  - a new sign-in ends the old tokens.
- `tests/integration/moderation.test.ts`: a ban also ends the previous token.
- `tests/services/authService.test.ts`: the new repository methods, and the ban check on a reissue.

**Compatibility:** build 11 reads only `body.token`, so it simply gets fewer unexpected sign-outs. The new app doesn't depend on this change.

### BE3. `/auth/logout` also switches off the account's push token — **S**
**App side:** B2.

`/auth/logout` finds the user from the refresh cookie, which still works after the access token has expired. That makes it the one call that can stop pushes when someone logs out with an old token. There is one session and one push token per user, so switching off by user id is right.

**Contract:** the request and response are unchanged. New side effect: the user's push token rows get `isActive = false` and `failureReason = 'logged_out'`. Registering at the next sign-in switches them back on, through the existing upsert.

**Changes**
- `services/pushNotificationService.ts`: export a new `deactivatePushTokensForUser(userId, reason)`.
- `routes/auth.ts`, `/logout`: after `disconnectUser(userId)`, call it inside a try/catch that only logs, so the cookie is always cleared.
- Optional: `moderationService.deactivatePushTokens` reuses it.

**Tests:** in `tests/integration/auth.test.ts`:
- logout switches off the push token, including with an expired access token;
- a cookie from a replaced session leaves pushes on;
- signing in and registering switches them on again.

**Compatibility:** this helps build 11 without an app update. If one account can ever be signed in on several devices, scope it to the device that is logging out.

### BE4. iPhone notifications play a sound — **XS**
**App side:** none.

**Contract:**
- Each FCM message gets `apns.payload.aps.sound = 'default'`, next to the existing `apns-priority: 10` header.
- It also gets `android.notification.sound = 'default'` for Android 7, which has no notification channels. Android 8+ already plays a sound through the `bleya_messages` channel.
- The badge count is BE9, for app builds that can clear it.

**Changes:** `services/pushNotificationService.ts`, `sendPushNotifications`.

**Tests:** extend `tests/services/pushNotificationService.test.ts`, which already records the messages passed to `sendEach`. `tests/integration/socketPush.test.ts` still passes.

**Compatibility:** build 11's iPhone pushes start playing a sound as soon as this deploys. Every public-room message push will also make a sound on iPhones, as it already does on Android.

### BE5. Ban and suspension text on the socket matches sign-in — **XS**
**App side:** none. A mobile test pins the parsing.

**Contract:** when a banned or suspended account connects, the rejection becomes `Account blocked: ` followed by `describeEnforcementForUser(user)`, for example `Account blocked: Your account is suspended until 2026-10-07. Reason: Spam`. The prefix is unchanged. A banned sender's `send_message` rejection (`FORBIDDEN`) carries the same sentence.

**Changes**
- `server/socket.ts`: in the `io.use` handshake, use `describeEnforcementForUser` instead of `isUserBlockedFromActing().reason`.
- `services/messageService.ts`: the sender check in `createMessage` uses the same sentence.

**Tests:** `tests/integration/realtime.test.ts` (the suspended and banned wording) and `tests/services/messageService.test.ts`.

**Compatibility:** build 11 shows the full sentence as soon as this deploys.

### BE6. `message_removed` also reaches chat lists and Activity — **S**
**App side:** D2.

**Contract:**
- The payload becomes `{messageId, roomId, parentMessageId | null, userId, createdAt}`. `userId` is the removed message's author. `createdAt` is its creation time in ms, the same value as `createdAt` in message payloads and `lastMessageTime` in chat-list payloads.
- It is sent in **one emit per removed message**, so each socket gets it once. It goes to:
  - the room, as today;
  - `user:<id>` for every member of the room, when the message is top-level;
  - `user:<id>` for every user whose notification was deleted with it.
- It goes out after the soft delete and the notification clean-up are saved.
- It is sent by `DELETE /v1/admin/messages/:id` and `POST /v1/admin/users/:id/remove-messages`. A restore still sends nothing.

**Changes**
- `server/socket.ts`: `emitMessageRemoved(payload, alsoToUserIds)` emits to the room and the user channels in one call.
- `services/moderationService.ts`:
  - `deleteNotificationsForMessages` returns who lost a notification;
  - add `getRoomMemberIds(roomId)`;
  - `deleteMessage` and `removeUserMessages` pass the author, `createdAt` and the recipients.

**Tests:** in `tests/integration/realtime.test.ts`:
- a top-level removal reaches members outside the room, the room and Activity recipients, once each;
- a reply removal reaches only the room and its Activity recipients;
- a bulk removal sends one event per message.

**Compatibility:**
- **Build 11 on the new backend:** it ignores the new fields. There is still one emit per message, so each socket gets it once and reply counts drop once, as today.
- **New app on today's backend:** it hears removals only while inside the room, as today.

### BE7. Passkey origins for Play installs — **XS**
**App side:** E1. Website: H1.

**Configuration, no code.** In Railway (production), `PASSKEY_EXPECTED_ORIGINS` must be:
```
https://bleyachat.com,android:apk-key-hash:<Play app-signing key>,android:apk-key-hash:frIBwEielUZ40bb-OLsXTEDf8VZHels3kCH9_ojSUtM
```
The last value is the upload key. The Play value is the base64url encoding, without padding, of the Play app-signing certificate's SHA-256:
```
FP='AA:BB:…'; echo "android:apk-key-hash:$(echo "$FP" | tr -d ':' | xxd -r -p | base64 | tr '+/' '-_' | tr -d '=')"
```
The list is comma-separated and matched exactly: no quotes and no trailing slash. Remove the local debug key's origin from production if it's there. Set this **before** H1 goes live, or Android could create passkeys that the server then refuses.

**Optional startup check** (recommended): `config/index.ts` gets `findPasskeyOriginProblems(origins, rpId)`. In production, `reportConfigGaps()` in `server/app.ts` logs `config.passkey_origins` when:
- `https://<rpId>` is missing;
- there's no Android origin;
- an Android origin is malformed: padding, `+` or `/`, or pasted hex.

This only logs and never stops startup.

**Docs:** update the comment and example in `.env.example`, the `PASSKEY_EXPECTED_ORIGINS` line in `README.md`, and the Play App Signing item in `TODO.md`.

**Compatibility:** adding origins only widens what's accepted, so build 11 works as soon as both changes are live.

### BE9. iOS app-icon badge — **M**
**App side:** C3.

**Contract**
- `POST /v1/notifications/push/register` accepts an optional `badge: true`, stored on the push token. Build 11 never sends it, so its pushes never carry a badge it couldn't clear.
- For tokens with `badge: true`, each push sets `apns.payload.aps.badge` to the recipient's count: unread Activity items plus DM rooms with unread messages, capped at 99. City rooms don't count; this is the same number the app shows (C3).
- Android ignores it, because launchers show their own notification dots.

**Changes**
- `models/PushToken.ts`: a `badge` flag.
- `routes/notifications.ts` and `registerPushToken` in `pushNotificationService.ts`: accept and store the flag.
- `sendPushNotifications`: for flagged iOS tokens, compute the count per recipient (one count query each, only for recipients being pushed) and set `aps.badge`.

**Tests:** extend `tests/services/pushNotificationService.test.ts`:
- a flagged iOS token gets `aps.badge` with the right count;
- an unflagged token gets none;
- Android messages are unchanged;
- registering without the flag keeps working.

**Compatibility**
- **Build 11 on the new backend:** it never registers with `badge: true`, so nothing changes for it.
- **New app on today's backend:** it gets no badge counts in pushes. The app still updates the badge itself while it runs.

---

## Optional (your call)

- **A "Child safety" report reason.** Add `child_safety` to `REPORT_REASONS` in `models/Report.ts` **before** any app sends it, since today's backend rejects unknown reasons. Recommended soon after launch; Play doesn't require it.
- **After launch:** hide Activity items that quote a thread whose author you blocked (`NotificationService.getNotifications`, its unread count, and the recipients in `createMessage`). I found this while planning; it isn't in the review.
- **After launch:** small server-side avatar thumbnails, so avatars aren't downloaded again at full size on every launch.

## Deliberately not changing

- **The 2,000-character cap** keeps truncating silently, as a safety net for old builds. The new app never sends more (F1).
- **The upload check in `routes/users.ts`** keeps refusing `application/octet-stream`. The app now labels photos `image/jpeg` (F2), and sharp stays the real check. Accepting any type would mean buffering arbitrary 5 MB uploads.
- **`/notifications/push/unregister`** stays for build 11, although the new app no longer calls it.
- **Profile-photo checks** keep accepting a photo when the automatic check can't run (your choice).
- **No multi-device push.** The server keeps one push token per account, so with one account on two phones, only the last one to sign in gets pushes. That's fine for launch.
