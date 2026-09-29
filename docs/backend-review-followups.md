# Bleya Mobile — Backend Review Follow-ups

**Status:** M1–M11 implemented on September 29, 2026 (not yet released). Needs the device checks at the end
before release. The backend side shipped on September 28, 2026 (backend commit `bdbac18`).
**Last updated:** September 29, 2026

## Why this exists
A full review of the backend fixed a set of security, moderation and reliability issues on the server.
Most fixes work for the current app as-is. Some only take full effect once the app changes too, and two
backend safeguards stay **switched off** until the app catches up:
- `SOCKET_ENFORCE_TOKEN_EXPIRY`: disconnect sockets whose access token expired (needs M1).
- `REQUIRE_PROVIDER_NONCE`: require a nonce on Google sign-in (needs M7).

## Already fixed server-side (no app work)
- Messages, bios and ban reasons no longer show `&#39;` / `&amp;` (text is stored as typed; old rows migrated).
- Sign-in and refresh of a banned/suspended account return `403` with a readable `error.message`. The
  sign-in screen already shows it in the red box.
- Blocked users no longer appear in `room_joined`, chat-list previews/unread counts or notifications.
- A socket event sent before joining a room returns an error containing "Not in a room" again, so the
  existing auto-rejoin works (it was showing "Open a chat first." as a SnackBar).
- Android Sign in with Apple: the backend callback no longer fails with 500.
- Profile photos are re-encoded server-side (metadata/GPS stripped). The upload request is unchanged.
- Notifications always carry a non-empty `sender.username` (falls back to "Unknown"), so one sender with
  a cleared username can't break the Activity tab.

## Order of work
1. **Before release:** M1, M2, M3.
2. **Next:** M4, M5, M6, M7.
3. **Then:** M8, M9, M10, M11.
4. **After rollout:** flip the backend flags (see the end).

## What was built (September 29, 2026)
All of M1–M11 below, plus four things the plan missed:
- **Mid-session token expiry (M1).** With `SOCKET_ENFORCE_TOKEN_EXPIRY` on, the server sends `TOKEN_EXPIRED` and
  then disconnects. `socket_io_client` never reconnects after a server-side disconnect, so the app refreshes and
  reconnects itself.
- **Reconnect after any server-side disconnect (M1).** A ban, a deploy or the per-user connection limit (5) end the
  socket without a reason. The app reconnects with backoff (1 s doubling to 60 s, reset after 30 s connected); the
  handshake then says what happened, and a ban signs the user out with the reason. The backoff keeps devices over
  the connection limit from disconnecting each other in a loop.
- **The early refresh (M2).** The refresh done before a request when the token is about to expire uses the same
  typed result. A ban found there signs the user out with the reason; before, the cookie was already cleared and the
  follow-up 401 lost it.
- **Backups (M3).** Android: `allowBackup="false"` plus `data_extraction_rules.xml`, since on Android 12+
  `allowBackup` doesn't cover phone-to-phone transfers (secure storage can't be decrypted on the new phone anyway).
  iOS: the Keychain survives deleting the app, so the first launch of a fresh install clears any stored session.

Also:
- The Google nonce (M7) is one per app launch, not one per attempt: google_sign_in 7.2 takes the nonce only in
  `initialize()`, which may run once. Once the app sends a nonce, the backend rejects a Google token without it
  even with `REQUIRE_PROVIDER_NONCE` off, so test Google sign-in on both platforms before release.
- Removing a thread reply now lowers its parent's reply count in the room list (replies aren't in that list, so the
  count never went down before).
- A sign-out while a refresh is in flight no longer brings the session back.
- `AuthRepository.refresh()` was removed with the other dead code in M11: it was a second, unused refresh path.
- Sending (M4) clears the input right away, as before, and puts the text back with the reason if the server
  doesn't store it. Anything typed meanwhile is kept on the next line. (Keeping the text until the
  acknowledgement arrived would resend it if the user kept typing.)
- Reconnects no longer rejoin a room whose screen was closed. A join adds the room back to the user's rooms and
  mutes its pushes, so a reconnect after leaving a room used to undo the leave.
- A forced rejoin (after `NOT_IN_ROOM`) reopens the thread on the server, so replies in an open thread don't also
  notify.
- The thread closes when its parent is removed even after a Retry, and closes itself rather than whichever screen
  is on top (e.g. a profile opened from the thread).
- Tests: 55 new (153 total), covering refresh outcomes, socket error handling, the cookie move, sends, removals,
  member paging and the error mapper.

**Known gap (backend):** a banned or suspended user who reopens the app after the access token expired is signed
out without the reason. Banning deletes the refresh token, so `/auth/refresh` answers 401 before its 403 check. They
see the reason when they try to sign in again, and an open app gets it from the socket. To show it at refresh too,
keep the refresh token on ban/suspend and let the refresh's enforcement check answer 403 (it clears the token
itself). Side effect: a suspended user whose app never refreshed during the suspension stays signed in after it
ends.

---

### M1. Socket: handle handshake rejections, reconnect with a fresh token — **M (highest care)**
With `socket_io_client` 2.0.3+1, a handshake rejected by the server arrives on the socket-level
`'error'` event, not `'connect_error'`. As a result:
- `_handleAuthFailureIfNeeded` never runs for it: "Authentication error" never triggers the token
  refresh, and "Account blocked:" never logs the user out.
- `_ensureConnected()` waits only for `connect` / `connect_error`, so after a rejection the chat list and
  the notifications listener hang.
- The handshake rejection also shows up as a SnackBar in an open chat room.

A second problem: the token only reaches the server in the WebSocket upgrade `Authorization` header,
fixed when the engine is created. The `auth` map set on the Manager never arrives, so a refreshed
token isn't used on reconnect.

Files:
- `lib/services/socket_service.dart`: setup ~84-91, `onError`/`onConnectError` ~119-131,
  `_handleAuthFailureIfNeeded` ~152-193, connect/`_ensureConnected` ~271-313, error parsing ~461-469
  and ~519-532.
- `lib/providers/auth_providers.dart` ~246-266.

Changes:
1. Build the socket with `OptionBuilder().setAuthFn((cb) => cb({'token': _currentToken}))` (supported in
   2.0.3+1). It is called on every connect and reconnect, and the backend reads `handshake.auth.token`
   first. Keep the `Authorization` header as a fallback.
2. Route socket-level `'error'` payloads that are handshake rejections into `_handleAuthFailureIfNeeded`:
   - message starts with `Authentication error` → refresh the token, then reconnect;
   - starts with `Account blocked:` → stop reconnecting and log out with the reason;
   - starts with `Server unavailable:` → do nothing; socket.io retries with backoff (it's a temporary
     backend or database problem, **not** an auth problem).
   Don't show these in the chat-room SnackBar.
3. Complete `_ensureConnected()` (as a failure) on those rejections, so nothing waits forever.
4. Read the ban reason from the payload's `message` field instead of stringifying the Map. Today the
   dialog text ends with a stray `}`.

Done when:
- An expired token refreshes silently and reconnects.
- A banned user is logged out and sees the reason, without the stray `}`.
- A database outage causes retries, not a logout.
- `_ensureConnected` never hangs.

### M2. Only log out when the session really ended — **S**
Today any failed refresh (429 rate limit, 5xx, timeout, offline) returns `null`, which logs the user
out on the 401 path. A 403 from refresh (ban) logs out silently, without the reason.

Files: `lib/services/auth_manager.dart` ~65-100, `lib/providers/auth_providers.dart` ~165-209.

Backend contract for `POST /v1/auth/refresh`:
- `200 {token}`: success.
- `401`: invalid or expired session.
- `403` with code `USER_BLOCKED` and a readable `error.message`: banned or suspended.

The refresh cookie is cleared only for 401/403; transient failures keep it.

Change:
- Return a typed result from refresh: `success(token)`, `sessionEnded(message?)` (401/403) or
  `transient` (429, 5xx, timeout, offline).
- Log out only on `sessionEnded`, and show a 403 message through the existing
  `fatalAuthMessageProvider` / `AppDialog`.
- On `transient`, keep the session and let the request fail with a retryable error.

Done when: airplane mode, a server error or a 429 never log the user out, and a banned user sees why.

### M3. Keep the refresh token in secure storage — **S–M**
The 365-day refresh cookie is written by `PersistCookieJar(storage: FileStorage('$basePath/cookies'))`
(`lib/services/auth_manager.dart:47`, set up from `lib/main.dart:40`). That is a plain file that can end
up in device backups.

Change:
- Give `PersistCookieJar` a custom `Storage` backed by `flutter_secure_storage`, which is already a
  dependency (Keychain on iOS, Keystore on Android).
- On first launch after the update, move the existing cookie file into secure storage and delete the
  file, so users stay signed in.

Done when: the refresh token isn't in the app's files or backups, and existing users aren't logged out
by the update.

### M4. Use the `send_message` acknowledgement — **S**
Today the input is cleared as soon as the message is sent. If the server rejects it (content filter,
not in a room, rate limit, ban), the text is lost.

Backend: `emit('send_message', {text, parentMessageId?}, ack)`. The ack is
`{ok: true, message}` or `{ok: false, error: {code, message}}`, and the `'error'` event is still
emitted for older clients.

Files: `lib/services/socket_service.dart` ~424-442, `lib/pages/chat_room_page.dart` ~117-128,
`lib/pages/thread_view_page.dart` ~75-85, `lib/providers/chat_room_providers.dart`.

Change:
- Use `emitWithAck` with a timeout of about 10 s.
- Clear the input only when `ok`. On error, keep the text and show `error.message`.
- On code `NOT_IN_ROOM`, rejoin and retry once.
- Don't also show the duplicate `'error'` event for the same send.

Done when: a rejected message stays in the input with a visible reason.

### M5. Moderation removals and blocks on open screens — **S**
- `message_removed` now also carries `parentMessageId` (`null` for top-level messages). In
  `ThreadController` (`lib/providers/chat_room_providers.dart` ~113-140): if the removed message is the
  open thread's parent, close the thread with a short notice.
- After blocking someone (`lib/pages/user_details_page.dart` ~264, message long-press in
  `lib/pages/chat_room_page.dart` ~159), remove that user's messages from `roomMessagesProvider`
  straight away. The server already stops sending them.

### M6. Match `NOT_IN_ROOM` by code — **XS**
The error payload is `{error: {code: 'NOT_IN_ROOM', message: 'Not in a room. …'}}`. In
`lib/providers/chat_room_providers.dart` ~316-341, check `code == 'NOT_IN_ROOM'`. Keep the text
match as a fallback.

### M7. Nonce for Google sign-in — **S**
Google ID tokens are currently not bound to the sign-in attempt.

Change:
- Generate a raw nonce with the same helper as Apple (`lib/services/provider_auth_service.dart` ~115-119).
- Pass it to `GoogleSignIn.instance.initialize(nonce: …)` (supported in google_sign_in 7.2.0).
- Send it as `rawNonce` in `POST /v1/auth/provider-sign-in`
  (`lib/data/repositories/auth_repository_impl.dart` ~64-81).

The backend accepts a token nonce equal to `rawNonce` or to its SHA-256 (base64url). Apple sign-in
already sends one, and the backend now requires it there.

### M8. "Under 15" report reason — **XS**
The backend accepts the reason `underage`. Add `ReportReason.underage` (wire value `underage`, label
"Under 15") to `lib/domain/entities/report_reason.dart` and the reason sheet in
`lib/widgets/report_actions.dart`. It is most useful on user reports.

### M9. Passkey management in Settings — **M**
Backend:
- `GET /v1/auth/passkeys` returns `[{id, deviceType, backedUp, createdAt, lastUsedAt}]`.
- `DELETE /v1/auth/passkeys/:id` returns `{hasPasskey}`.
- Registration (`POST /v1/auth/passkeys/registration/options`) and deletion now need a sign-in within
  the last 30 minutes, from the current session. Otherwise they return
  `403 "For your security, please sign in again before changing your passkeys."`.
  Onboarding registration (right after sign-in or choosing a username) is unaffected.

Change:
- Add a Settings → Passkeys page: list the passkeys, delete one (with confirmation), and add a passkey.
- On a 403, offer "Sign in again".
- `lib/utils/passkey_onboarding.dart:29` tells users they can add a passkey later in Settings, which
  isn't possible today. This page makes it true.

### M10. Room member paging — **S**
`GET /v1/rooms/:id/members?limit=&offset=` returns a bare array sorted by username. The default limit
is 500 and the maximum 1000, so bigger rooms are cut off without paging.

Change: load pages of about 100 with infinite scroll in `lib/data/repositories/room_repository_impl.dart`
~114-139 and `lib/pages/room_details_page.dart`. The "N members" label shouldn't assume it has the full
list.

### M11. Small hardening — **XS each**
- `lib/widgets/notification_tile.dart` ~133-139: guard `NetworkImage` against invalid URLs and add an
  error fallback, like `ProfileAvatar` does.
- `lib/core/errors/api_error_mapper.dart` ~14-22: tolerate `details` that isn't a Map instead of
  throwing on the cast.
- Remove dead code for server surfaces that no longer exist:
  - `getMyInfo()` (`GET /v1/auth/me`),
  - `getAvailableRooms()` / `availableRoomsProvider` (`GET /v1/rooms`),
  - `onUserJoined` / `onUserLeft` (the `user_joined` / `user_left` events are gone).

---

## Backend flags to flip afterwards (Railway → Variables)
| Flag | Turn on when | Effect |
|---|---|---|
| `SOCKET_ENFORCE_TOKEN_EXPIRY=true` | M1 is released and most users have updated | Sockets are disconnected when their access token expires. The app gets `Authentication error: session expired` and refreshes. |
| `REQUIRE_PROVIDER_NONCE=true` | M7 is released and older builds are gone (force-update or wait) | Google sign-in without a matching nonce is rejected. |

## Test checklist (device, against production or staging)
- Ban a test account via `POST /v1/admin/users/:id/ban`:
  - the open app is logged out and shows the reason;
  - signing in again shows the ban message;
  - no pushes arrive.
- Suspend with a date, then unban: sign-in is refused, then works again.
- Block a user in a public room: their messages disappear right away and stay hidden after reopening
  the chat and in the chat list.
- Remove a message via `DELETE /v1/admin/messages/:id`:
  - it disappears live;
  - an open thread on it closes;
  - its notification is gone.
- Send a profane message: the text stays in the input with the filter message (M4).
- Turn on airplane mode, wait past the token lifetime, reconnect: still signed in (M2).
- Upload a profile photo: the new photo shows. Settings → Passkeys lists and deletes (M9).
- Settings → Passkeys more than 30 minutes after signing in: adding or deleting offers "Sign in again" (M9).
- Install this build over the previous one while signed in: still signed in (cookie moved to secure storage, M3).
- iOS: delete the app while signed in, reinstall: starts signed out (M3).
- Google sign-in on iOS and on Android: works with the nonce (M7). Check the logs for a nonce mismatch.
- A room with more than 100 members: the label reads "100+ members" and scrolling loads the rest (M10).
- Leave the app open past the token lifetime with `SOCKET_ENFORCE_TOKEN_EXPIRY=true` on staging: the socket
  reconnects silently and messages keep arriving (M1).
