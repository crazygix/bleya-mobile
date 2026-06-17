# Bleya Mobile — Parity & Release Plan

**Status:** Plan, not started. Review before implementing.
**Last updated:** June 17, 2026

## Where things stand
The mobile app is **behind the backend and not yet releasable**, but the architecture is in good
shape — Dio HTTP client, repository/use-case/provider layering, and shared `AppSheet`/`AppDialog`/
`AppToast`/`AppError` patterns already exist, so almost everything below is a vertical slice that
reuses them. Only one new runtime dependency is needed (`url_launcher`). Work splits into two groups:
**A — get on par with the backend** (match the moderation/safety features just shipped server-side),
and **B — make it store-releasable** (App Store / Play blockers).

---

## Group A — On par with the backend

### A1. Send Apple `authorizationCode` at sign-in — **XS**
Backend revocation (Apple Guideline 5.1.1(v)) needs it; the app currently captures it then throws it away.
- `lib/services/provider_auth_service.dart` — add `final String? authorizationCode;` to `ProviderAuthCredential`; set it from `credential.authorizationCode` in `signInWithApple()` (Apple only; Google has none).
- `lib/data/repositories/auth_repository_impl.dart` — add `if (credential.authorizationCode != null) 'authorizationCode': credential.authorizationCode` to the Apple `/auth/provider-sign-in` body. (The Dio log-sanitizer in `lib/providers/auth_providers.dart:85` already lists this key.)

### A2. Handle the `message_removed` socket event — **S**
Server emits `message_removed { messageId, roomId }`; today nothing listens, so a moderated message
stays on screen until reload.
- `lib/services/socket_service.dart` — add `MessageRemovedData` + `parseMessageRemovedPayload` (mirror `parseMessagePayload`); optional typed `onMessageRemoved` helper.
- `lib/providers/chat_room_providers.dart` — in `ChatRoomController._setupSocketListeners` register a `message_removed` listener: guard `roomId`, drop the message from `roomMessagesProvider(roomId)`, and decrement the parent's `replyCount` if it was a reply. Mirror in `ThreadController` for open threads. Remove both listeners in each `dispose()`.

### A3. Handle ban/suspend handshake rejection — **S–M (highest care)**
A banned user is rejected at the socket handshake with a message **not** prefixed `"Authentication
error"`. Today that falls through, is debug-printed only, and the client keeps silently reconnecting.
- `lib/services/socket_service.dart` — in `_handleAuthFailureIfNeeded` (and the inline connect-error handler + `onConnectError`/`onError` registrations): **keep the `contains('Authentication error')` refresh branch unchanged** (token-refresh depends on it), and add an else-branch for any other handshake error that (a) clears the token + disconnects so socket.io stops reconnecting, (b) fires a new `onFatalError(message)` callback. Add the callback field next to `refreshToken`.
- `lib/providers/auth_providers.dart` — wire `service.onFatalError` in `socketServiceProvider` to show the server message (`AppDialog.alert`) and call `authManager.logout()` (which already disconnects, clears token, bumps sessionVersion, routes to `/`).
- Optional: special-case a ban-specific **403** in `lib/core/errors/api_error_mapper.dart` to force logout rather than a generic toast.

### A4. Surface socket send / content-filter errors — **S**
Sending is over the socket and is fire-and-forget; a content-filter `VALIDATION_ERROR` (or 403) on a
sent message currently shows the user nothing.
- `lib/providers/chat_room_providers.dart` — `ChatRoomController._errorHandler` (~lines 230-249) currently only handles `'Not in a room'`; surface other user-safe socket `error` messages via a state field/stream.
- `lib/pages/chat_room_page.dart` — subscribe and `AppToast.showError(socketError.message)`. (Backend already sends user-safe text via `emitSocketError`.)

### A5. Report UI — **M–L**
Backend `POST /v1/reports { reportedUserId?, roomId?, messageId?, reason, details? }` is live and unused.
- New `lib/domain/entities/report_reason.dart` — `enum ReportReason { spam, harassment, inappropriateContent, impersonation, other }` with `apiValue` (`inappropriate_content` etc.).
- New `lib/domain/repositories/report_repository.dart` + `lib/data/repositories/report_repository_impl.dart` (`POST /reports`, mirror `RoomRepositoryImpl.blockDirectChat`), `lib/use_cases/report/create_report_use_case.dart`, and providers in `repository_providers.dart` / `use_case_providers.dart`.
- Reason picker via `AppSheet.actions<ReportReason>()`; optional details field.
- Entry points: message long-press (`lib/widgets/swipeable_message_bubble.dart` → `chat_room_page.dart` — neither bubble has `onLongPress` today, so add it), user profile (`lib/pages/user_details_page.dart`), room overflow (`lib/pages/room_details_page.dart`).

---

## Group B — Release-ready (store blockers)

### B1. Delete-account + Export-my-data UI — **M**
Required by Apple 5.1.1(v) and Play; backend `DELETE /v1/users/me` and `GET /v1/users/me/export` exist.
- `lib/domain/repositories/user_repository.dart` + `..._impl.dart` — add `deleteAccount()` and `exportMyData()`.
- `lib/use_cases/user/` — `delete_account_use_case.dart`, `export_data_use_case.dart` + providers.
- `lib/pages/settings_page.dart` — add **Delete account** (destructive `AppDialog.confirm` → delete → `authManager.logout()`) and **Export my data** items near Log Out.

### B2. Tappable Terms/Privacy + affirmative consent — **S–M**
Pages are live at `bleyachat.com/terms` and `/privacy`.
- `pubspec.yaml` — add `url_launcher`. `lib/constants/urls.dart` — add `termsUrl`, `privacyUrl`, `deleteAccountUrl`.
- `lib/pages/intro_page.dart` (~lines 152-159) — replace static consent text with tappable links; `lib/pages/authorisation_page.dart` — add an affirmative acceptance step gating the sign-in buttons.
- `lib/pages/settings_page.dart` — replace the `_showComingSoon('Privacy')` stub with real Terms/Privacy links.

### B3. Block reachable beyond DMs — **S–M (needs a decision)**
Block is currently only reachable from an existing DM (`UserDetailsPage` gated on `directChatStatus.hasChat`). Make it reachable from a public-room member profile, a message author, and a no-DM profile.
- `lib/pages/user_details_page.dart` — relax the `hasChat` gating; add Block (and Report) to the header action sheet. `lib/widgets/*message_bubble.dart` — Block author on long-press. `lib/pages/room_details_page.dart` / `room_member_tile.dart` — block from a member tile.
- **Decision:** the block endpoint is DM-scoped (`/rooms/direct/:id/block`). Either confirm it works user-to-user without an existing DM, auto-create-then-block, or add a user-level block path on the backend.

### B4. Branded app icons — **M (needs final art)**
Both platforms currently ship the **default Flutter placeholder icon** — an automatic store rejection.
- Add `flutter_launcher_icons` (dev) and generate; replaces `ios/Runner/Assets.xcassets/AppIcon.appiconset/*` and `android/.../mipmap-*/ic_launcher.png` + the adaptive `mipmap-anydpi-v26/ic_launcher.xml` foreground.

### B5. iOS launch screen + Android notification icon — **S–M**
- iOS launch screen is a blank 1×1 `LaunchImage` — add branded art (`flutter_native_splash` or edit `LaunchScreen.storyboard`).
- Android has no FCM notification icon — add a white-silhouette `ic_stat_notification` drawable and `<meta-data android:name="com.google.firebase.messaging.default_notification_icon" .../>` in `AndroidManifest.xml` (otherwise notifications show a gray square).

### B6. iOS Info.plist + privacy manifest — **S**
- `ios/Runner/Info.plist` — add `ITSAppUsesNonExemptEncryption = false` (skips the export-compliance prompt each upload).
- Add `ios/Runner/PrivacyInfo.xcprivacy` (data-collection + required-reason API declarations) and register it in the Runner target — Apple now flags apps missing it.

### B7. Version bump — **XS**
`pubspec.yaml` is at `0.0.1+9`; set a real release version (e.g. `1.0.0+1`).

---

## Recommended build order
Most of this parallelizes. Suggested sequence:
1. **Quick parity wins first:** A1 (Apple code), A2 (`message_removed`), A4 (socket error toast).
2. **A3 ban handling** — careful, isolated to `socket_service.dart` + `auth_providers.dart`; don't regress the `Authentication error` refresh path (test both).
3. **B1 delete/export** and **B2 legal links + consent** — straightforward, unblock store requirements.
4. **A5 Report UI** and **B3 block reachability** — the larger UI slices (share the same entry points/sheets).
5. **Assets/config in parallel anytime art exists:** B4 icons, B5 launch/notification icon, B6 Info.plist/privacy manifest, B7 version.
6. Smoke-test on device: delete/re-signin, report flow, ban (kick + message + no reconnect loop), live message removal, legal links, passkeys (AASA is live).

## Open decisions
- **Minimum age:** legal docs say **15**, backend TODO says **13**, store-rating guidance suggested **17+**. Pick one and align the Terms copy, store age rating, and any consent screen. (Blocks store submission.)
- **Affirmative Terms acceptance:** add an explicit checkbox/affirmative button at signup, or keep passive consent with tappable links?
- **Block-from-non-DM mechanism:** confirm the DM-scoped endpoint works user-to-user, auto-create-then-block, or add a user-level block.
- **Export UX:** share sheet vs. save-to-file vs. on-screen.
- **Ban 403:** should a ban-specific 403 on a REST action force logout, or just toast?
- **Branding art:** final icon + launch art needs to be produced (external).
