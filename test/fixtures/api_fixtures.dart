/// Backend responses and socket events, shaped exactly as the backend sends
/// them, for the data-layer tests.
///
/// Each fixture names the backend code that builds it (paths are in the
/// backend repository). Nulls and empty strings are kept as the backend sends
/// them: `|| null` and `|| ''` in a serializer become `null` and `''` here.
/// When a backend response changes, change its fixture in the same change
/// (see rules/api-contract-rules.md).
///
/// Every function returns a fresh map, so a test can change it freely.
library;

/// Ids as the backend sends them: ObjectIds as 24-character hex strings, and
/// a slug for a city.
abstract final class FixtureIds {
  /// The signed-in user.
  static const me = '66f0a1b2c3d4e5f600000001';

  /// Another user: the DM partner, and the author of the messages.
  static const otherUser = '66f0a1b2c3d4e5f600000002';
  static const cityRoom = '66f0a1b2c3d4e5f6000000a1';
  static const directRoom = '66f0a1b2c3d4e5f6000000a2';

  /// A top-level message, which is also the thread its replies belong to.
  static const message = '66f0a1b2c3d4e5f6000000b1';
  static const reply = '66f0a1b2c3d4e5f6000000b2';
  static const secondReply = '66f0a1b2c3d4e5f6000000b3';
  static const olderMessage = '66f0a1b2c3d4e5f6000000b0';
  static const notification = '66f0a1b2c3d4e5f6000000c1';
  static const passkey = '66f0a1b2c3d4e5f6000000d1';
  static const challenge = '66f0a1b2c3d4e5f6000000e1';
  static const report = '66f0a1b2c3d4e5f6000000f1';
  static const city = 'belgrade-rs';
}

/// Times as the backend sends them: milliseconds since the epoch.
abstract final class FixtureTimes {
  /// When both accounts were created: 2025-12-01 00:00 UTC.
  static const accountCreated = 1764547200000;

  /// Last sign-in: 2026-01-01 08:00 UTC.
  static const lastLogin = 1767254400000;

  /// The message before [sent]: 2026-01-01 11:55 UTC.
  static const olderSent = 1767268500000;

  /// The top-level message: 2026-01-01 12:00 UTC.
  static const sent = 1767268800000;

  /// The first reply: 2026-01-01 12:05 UTC.
  static const replied = 1767269100000;

  /// The second reply: 2026-01-01 12:10 UTC.
  static const repliedAgain = 1767269400000;

  /// When the room was last read: 2026-01-01 12:15 UTC.
  static const read = 1767269700000;
}

const _photoUrl =
    'https://cdn.example.com/profiles/profile-3f1c9a52-0d4e-4b7a-9c61-2a8e5d7f4b10.webp';
const _cityImageUrl = 'https://cdn.example.com/cities/belgrade-rs.webp';
const _cityRoomName = 'Belgrade, Serbia';
const _messageText = 'Anyone up for coffee near Knez Mihailova?';
const _replyText = 'Count me in!';

// ---------------------------------------------------------------------------
// Messages
// ---------------------------------------------------------------------------

/// A message, as `formatMessage` (utils/message.ts) formats it: the items of
/// every message list, the `new_message` event, and the `message` of a
/// `send_message` acknowledgement. `parentMessageId` is null for a top-level
/// message, and `username` is '' when the author has none.
Map<String, dynamic> messageJson({
  String id = FixtureIds.message,
  String roomId = FixtureIds.cityRoom,
  String userId = FixtureIds.otherUser,
  String username = 'ana',
  String text = _messageText,
  int createdAt = FixtureTimes.sent,
  String? parentMessageId,
  int replyCount = 0,
}) {
  return {
    'id': id,
    'roomId': roomId,
    'userId': userId,
    'username': username,
    'text': text,
    'createdAt': createdAt,
    'parentMessageId': parentMessageId,
    'replyCount': replyCount,
  };
}

/// A thread reply, as `formatMessage` (utils/message.ts) formats it. Replies
/// never have replies of their own.
Map<String, dynamic> replyJson({
  String id = FixtureIds.reply,
  String userId = FixtureIds.me,
  String username = 'mila',
  String text = _replyText,
  int createdAt = FixtureTimes.replied,
}) {
  return messageJson(
    id: id,
    userId: userId,
    username: username,
    text: text,
    createdAt: createdAt,
    parentMessageId: FixtureIds.message,
  );
}

/// `GET /rooms/:roomId/messages`: `getRoomMessagesForUser`
/// (services/roomService.ts). Messages are oldest first; `nextCursor` is
/// `<createdAt>_<id>` of the oldest, or null for an empty page.
Map<String, dynamic> roomMessagesPageJson({bool hasMore = true}) {
  return {
    'messages': [
      messageJson(
        id: FixtureIds.olderMessage,
        userId: FixtureIds.me,
        username: 'mila',
        text: 'Good morning, Belgrade!',
        createdAt: FixtureTimes.olderSent,
      ),
      messageJson(replyCount: 2),
    ],
    'pagination': {
      'hasMore': hasMore,
      'nextCursor': '${FixtureTimes.olderSent}_${FixtureIds.olderMessage}',
    },
  };
}

/// `GET /messages/:messageId/thread` (routes/messages.ts): the parent and
/// its replies, oldest first.
Map<String, dynamic> threadJson() {
  return {
    'parentMessage': messageJson(replyCount: 2),
    'replies': [
      replyJson(),
      replyJson(
        id: FixtureIds.secondReply,
        userId: FixtureIds.otherUser,
        username: 'ana',
        text: 'Great, see you at 5.',
        createdAt: FixtureTimes.repliedAgain,
      ),
    ],
  };
}

/// `POST /rooms/:roomId/read`: `markRoomReadForUser`
/// (services/roomService.ts).
Map<String, dynamic> markRoomReadJson() {
  return {
    'message': 'Room marked as read',
    'lastReadAt': FixtureTimes.read,
  };
}

// ---------------------------------------------------------------------------
// Rooms
// ---------------------------------------------------------------------------

/// A city room in `GET /rooms/joined`: `getJoinedRoomsForUser`
/// (services/roomService.ts).
Map<String, dynamic> joinedCityRoomJson({int unreadCount = 3}) {
  return {
    'id': FixtureIds.cityRoom,
    'name': _cityRoomName,
    'type': 'public',
    'cityKey': FixtureIds.city,
    'participants': <String>[],
    'otherUserId': null,
    'imageUrl': _cityImageUrl,
    'location': {'latitude': 44.80401, 'longitude': 20.46513},
    'lastMessageText': _messageText,
    'lastMessageTime': FixtureTimes.sent,
    'lastMessageUserId': FixtureIds.otherUser,
    'lastMessageUsername': 'ana',
    'unreadCount': unreadCount,
  };
}

/// A DM without messages in `GET /rooms/joined`: `getJoinedRoomsForUser`
/// (services/roomService.ts). Its name and photo are the other user's, and
/// `imageUrl` is null when they have no photo.
Map<String, dynamic> joinedDirectRoomJson() {
  return {
    'id': FixtureIds.directRoom,
    'name': 'ana',
    'type': 'private',
    'cityKey': null,
    'participants': [FixtureIds.me, FixtureIds.otherUser],
    'otherUserId': FixtureIds.otherUser,
    'imageUrl': null,
    'location': null,
    'lastMessageText': null,
    'lastMessageTime': null,
    'lastMessageUserId': null,
    'lastMessageUsername': null,
    'unreadCount': 0,
  };
}

/// `GET /rooms/:roomId` for a city room: `getRoomDetailForUser`
/// (services/roomService.ts). It has no preview and no unread count.
Map<String, dynamic> roomDetailJson() {
  return {
    'id': FixtureIds.cityRoom,
    'name': _cityRoomName,
    'type': 'public',
    'cityKey': FixtureIds.city,
    'imageUrl': _cityImageUrl,
    'location': {'latitude': 44.80401, 'longitude': 20.46513},
    'participants': <String>[],
    'otherUserId': null,
  };
}

/// `POST /rooms/:roomId/join`: `joinRoomForUser` with `toRoomSummary`
/// (services/roomService.ts).
Map<String, dynamic> joinRoomResponseJson() {
  return {
    'message': 'Successfully joined room',
    'room': {
      'id': FixtureIds.cityRoom,
      'name': _cityRoomName,
      'type': 'public',
      'cityKey': FixtureIds.city,
      'imageUrl': _cityImageUrl,
      'location': {'latitude': 44.80401, 'longitude': 20.46513},
    },
  };
}

/// `POST /rooms/:roomId/leave`: `leaveRoomForUser`
/// (services/roomService.ts).
Map<String, dynamic> leaveRoomJson() {
  return {'message': 'Successfully left room'};
}

/// An item of `GET /rooms/:roomId/members`: `getRoomMembersForUser`
/// (services/roomService.ts). Missing values are ''.
Map<String, dynamic> roomMemberJson({
  String id = FixtureIds.otherUser,
  String username = 'ana',
  String bio = 'Coffee, trams and long walks.',
  String profileImageUrl = _photoUrl,
}) {
  return {
    'id': id,
    'username': username,
    'bio': bio,
    'profileImageUrl': profileImageUrl,
  };
}

/// `POST /rooms/direct/:otherUserId`: `openOrCreateDirectRoom`
/// (services/directMessageService.ts).
Map<String, dynamic> openDirectRoomJson() {
  return {
    'message': 'Direct message room ready',
    'room': {
      'id': FixtureIds.directRoom,
      'name': 'ana',
      'type': 'private',
      'participants': [FixtureIds.me, FixtureIds.otherUser],
      'imageUrl': _photoUrl,
      'otherUserId': FixtureIds.otherUser,
    },
  };
}

/// `GET /rooms/direct/:otherUserId/status`: `getDirectChatStatus`
/// (services/directMessageService.ts).
Map<String, dynamic> directChatStatusJson({
  bool isBlockedByMe = false,
  bool isBlockedByOtherUser = false,
}) {
  return {
    'hasChat': true,
    'roomId': FixtureIds.directRoom,
    'isBlockedByMe': isBlockedByMe,
    'isBlockedByOtherUser': isBlockedByOtherUser,
    'canSendMessage': !isBlockedByMe && !isBlockedByOtherUser,
    'isDeletedByMe': false,
  };
}

/// `POST /rooms/direct/:otherUserId/delete`: `deleteDirectChat`
/// (services/directMessageService.ts).
Map<String, dynamic> deleteDirectChatJson() {
  return {
    'message': 'Chat removed from your list.',
    'hasChat': true,
    'roomId': FixtureIds.directRoom,
    'deleted': true,
  };
}

/// `POST /rooms/direct/:otherUserId/block`: `blockDirectUser`
/// (services/directMessageService.ts).
Map<String, dynamic> blockDirectUserJson() {
  return {
    'message': 'User blocked.',
    'roomId': FixtureIds.directRoom,
    'blocked': true,
    'alreadyBlocked': false,
  };
}

/// `POST /rooms/direct/:otherUserId/unblock`: `unblockDirectUser`
/// (services/directMessageService.ts).
Map<String, dynamic> unblockDirectUserJson() {
  return {
    'message': 'User unblocked.',
    'roomId': FixtureIds.directRoom,
    'blocked': false,
    'alreadyBlocked': false,
  };
}

// ---------------------------------------------------------------------------
// Cities
// ---------------------------------------------------------------------------

/// An item of `GET /cities/nearby` (routes/cities.ts). `imageUrl` is null
/// until the city has an image.
Map<String, dynamic> nearbyCityJson({
  num latitude = 44.80401,
  num longitude = 20.46513,
  String? imageUrl = _cityImageUrl,
}) {
  return {
    'id': FixtureIds.city,
    'name': 'Belgrade',
    'country': 'RS',
    'countryName': 'Serbia',
    'latitude': latitude,
    'longitude': longitude,
    'imageUrl': imageUrl,
    'lastUpdated': FixtureTimes.accountCreated,
  };
}

/// `POST /cities/:cityId/join` (routes/cities.ts). Its room has no type and
/// no location.
Map<String, dynamic> joinCityJson() {
  return {
    'room': {
      'id': FixtureIds.cityRoom,
      'name': _cityRoomName,
      'cityKey': FixtureIds.city,
      'imageUrl': _cityImageUrl,
    },
  };
}

// ---------------------------------------------------------------------------
// Activity (notifications)
// ---------------------------------------------------------------------------

/// An item of `GET /notifications` (routes/notifications.ts): a reply to the
/// signed-in user's message. `sender.profileImageUrl` is null without a
/// photo, and `parentMessageText` is null when the parent has no text.
Map<String, dynamic> notificationJson({bool read = false}) {
  return {
    'id': FixtureIds.notification,
    'sender': {
      'id': FixtureIds.otherUser,
      'username': 'ana',
      'profileImageUrl': null,
    },
    'type': 'reply',
    'roomId': FixtureIds.cityRoom,
    'roomName': _cityRoomName,
    'roomType': 'public',
    'messageId': FixtureIds.reply,
    'threadId': FixtureIds.message,
    'parentMessageText': _messageText,
    'replyText': _replyText,
    'previewText': _replyText,
    'read': read,
    'isDismissed': false,
    'createdAt': FixtureTimes.replied,
  };
}

/// `GET /notifications` (routes/notifications.ts). `nextCursor` is the
/// oldest item's `createdAt`, or null on the last page.
Map<String, dynamic> notificationsPageJson({int? nextCursor}) {
  return {
    'notifications': [notificationJson()],
    'unreadCount': 1,
    'nextCursor': nextCursor,
  };
}

/// The `new_notification` socket event: `buildReplyNotificationEvents`
/// (services/NotificationService.ts). The list item plus `recipient` and
/// `updatedAt`.
Map<String, dynamic> notificationEventJson() {
  return {
    ...notificationJson(),
    'recipient': FixtureIds.me,
    'updatedAt': FixtureTimes.replied,
  };
}

/// `{success: true}`: `POST /notifications/push/register`, `/:id/read`,
/// `/read-all`, `/:id/dismiss` and `/dismiss-all`
/// (routes/notifications.ts).
Map<String, dynamic> successJson() {
  return {'success': true};
}

// ---------------------------------------------------------------------------
// Users
// ---------------------------------------------------------------------------

/// `GET /users/me`, `PUT /users/profile`, `POST /users/profile-image` and
/// `POST /auth/set-username`: `toUserProfileResponse`
/// (services/userService.ts). `profileImageUrl` and `bio` are '' when unset.
Map<String, dynamic> myProfileJson({
  String username = 'mila',
  String bio = '',
  String profileImageUrl = '',
}) {
  return {
    'id': FixtureIds.me,
    'username': username,
    'bio': bio,
    'profileImageUrl': profileImageUrl,
    'createdAt': FixtureTimes.accountCreated,
    'updatedAt': FixtureTimes.accountCreated,
    'lastLogin': FixtureTimes.lastLogin,
  };
}

/// `GET /users/:userId`: `getPublicProfile` (services/userService.ts). No
/// `lastLogin`.
Map<String, dynamic> publicProfileJson() {
  return {
    'id': FixtureIds.otherUser,
    'username': 'ana',
    'bio': 'Coffee, trams and long walks.',
    'profileImageUrl': _photoUrl,
    'createdAt': FixtureTimes.accountCreated,
    'updatedAt': FixtureTimes.accountCreated,
  };
}

/// An item of `GET /users/blocked` (routes/users.ts). Missing values are '',
/// and `blockedAt` is null for a block without a date.
Map<String, dynamic> blockedUserJson({int? blockedAt = FixtureTimes.read}) {
  return {
    'id': FixtureIds.otherUser,
    'username': 'ana',
    'bio': '',
    'profileImageUrl': '',
    'blockedAt': blockedAt,
  };
}

/// `POST /users/:userId/block` and `/unblock`: `blockUser` and
/// `unblockUser` (services/blockService.ts).
Map<String, dynamic> userBlockResultJson({required bool blocked}) {
  return {'blocked': blocked, 'alreadyBlocked': false};
}

/// `GET /users/me/export`: `exportUserData` (services/accountService.ts). The
/// export is a file for the user, so its times are ISO strings.
Map<String, dynamic> dataExportJson() {
  return {
    'exportedAt': '2026-01-02T09:30:00.000Z',
    'account': {
      'id': FixtureIds.me,
      'username': 'mila',
      'bio': '',
      'profileImageUrl': '',
      'createdAt': '2025-12-01T00:00:00.000Z',
      'updatedAt': '2025-12-01T00:00:00.000Z',
      'lastLogin': '2026-01-01T08:00:00.000Z',
      'hiddenDirectRoomIds': <String>[],
      'roomReadPointers': [
        {
          'roomId': FixtureIds.cityRoom,
          'lastReadAt': '2026-01-01T12:15:00.000Z',
        },
      ],
      'status': 'active',
      'suspendedUntil': null,
      'enforcementReason': '',
    },
    'linkedProviders': [
      {
        'provider': 'google',
        'email': 'mila@example.com',
        'emailVerified': true,
        'isPrivateRelay': false,
        'linkedAt': '2025-12-01T00:00:00.000Z',
        'lastUsedAt': '2026-01-01T08:00:00.000Z',
      },
    ],
    'passkeys': <Map<String, dynamic>>[],
    'pushDevices': [
      {
        'platform': 'ios',
        'createdAt': '2025-12-01T00:00:00.000Z',
        'lastSeenAt': '2026-01-01T08:00:00.000Z',
      },
    ],
    'rooms': [
      {
        'id': FixtureIds.cityRoom,
        'type': 'public',
        'name': _cityRoomName,
        'cityKey': FixtureIds.city,
        'otherParticipantIds': <String>[],
      },
    ],
    'messages': [
      {
        'id': FixtureIds.reply,
        'roomId': FixtureIds.cityRoom,
        'text': _replyText,
        'parentMessageId': FixtureIds.message,
        'createdAt': '2026-01-01T12:05:00.000Z',
        'removedByModerator': false,
      },
    ],
    'reportsFiled': <Map<String, dynamic>>[],
    'blockedUsers': <Map<String, dynamic>>[],
    'blockedByOthers': <Map<String, dynamic>>[],
    'notifications': <Map<String, dynamic>>[],
  };
}

/// `DELETE /users/me`: `deleteUserAccount` (services/accountService.ts).
Map<String, dynamic> deleteAccountJson() {
  return {
    'deleted': true,
    'removed': {
      'messages': 1,
      'notifications': 0,
      'blocks': 0,
      'passkeys': 0,
      'identities': 1,
      'authChallenges': 0,
      'pushTokens': 1,
    },
  };
}

// ---------------------------------------------------------------------------
// Sign-in and passkeys
// ---------------------------------------------------------------------------

/// `POST /auth/provider-sign-in` and `POST /auth/passkeys/authentication/verify`
/// (routes/auth.ts). The refresh token comes as a cookie, not in the body.
Map<String, dynamic> authSessionJson({
  String token = 'access-token-1',
  bool requiresUsername = false,
  bool hasPasskey = false,
}) {
  return {
    'token': token,
    'requiresUsername': requiresUsername,
    'hasPasskey': hasPasskey,
  };
}

/// `GET /auth/security`, `POST /auth/passkeys/registration/verify` and
/// `DELETE /auth/passkeys/:passkeyId`: `getSecurityStatus`
/// (services/authService.ts).
Map<String, dynamic> securityStatusJson({required bool hasPasskey}) {
  return {'hasPasskey': hasPasskey};
}

/// `POST /auth/passkeys/authentication/options`: `beginPasskeyAuthentication`
/// (services/authService.ts), with the options `generateAuthenticationOptions`
/// (@simplewebauthn/server 13) builds in services/passkeyService.ts.
Map<String, dynamic> passkeyAuthenticationOptionsJson() {
  return {
    'challengeId': FixtureIds.challenge,
    'options': {
      'rpId': 'bleyachat.com',
      'challenge': 'BefVJKDr19-eCXHteWKSGcQS6O1Yafx6pQxC-w-jb2I',
      'timeout': 60000,
      'userVerification': 'preferred',
    },
  };
}

/// `POST /auth/passkeys/registration/options`: `beginPasskeyRegistration`
/// (services/authService.ts), with the options `generateRegistrationOptions`
/// (@simplewebauthn/server 13) builds in services/passkeyService.ts.
Map<String, dynamic> passkeyRegistrationOptionsJson() {
  return {
    'challengeId': FixtureIds.challenge,
    'options': {
      'challenge': 'NpEKhAbeJfrOgMNt7drvVcmsDEEQhMOyecBHRlMC9Ug',
      'rp': {'name': 'Bleya', 'id': 'bleyachat.com'},
      'user': {
        'id': 'NjZmMGExYjJjM2Q0ZTVmNjAwMDAwMDAx',
        'name': 'mila',
        'displayName': 'mila',
      },
      'pubKeyCredParams': [
        {'alg': -8, 'type': 'public-key'},
        {'alg': -7, 'type': 'public-key'},
        {'alg': -257, 'type': 'public-key'},
      ],
      'timeout': 60000,
      'attestation': 'none',
      'excludeCredentials': <Map<String, dynamic>>[],
      'authenticatorSelection': {
        'residentKey': 'preferred',
        'userVerification': 'preferred',
        'authenticatorAttachment': 'platform',
        'requireResidentKey': false,
      },
      'extensions': {'credProps': true},
      'hints': <String>[],
    },
  };
}

/// An item of `GET /auth/passkeys`: `listPasskeys`
/// (services/authService.ts). `lastUsedAt` is null until first use.
Map<String, dynamic> passkeySummaryJson({int? lastUsedAt}) {
  return {
    'id': FixtureIds.passkey,
    'deviceType': 'multiDevice',
    'backedUp': true,
    'createdAt': FixtureTimes.lastLogin,
    'lastUsedAt': lastUsedAt,
  };
}

/// `POST /auth/check-username` (routes/auth.ts).
Map<String, dynamic> usernameAvailabilityJson({required bool available}) {
  return {'available': available};
}

// ---------------------------------------------------------------------------
// Reports
// ---------------------------------------------------------------------------

/// `POST /reports`, answered with 201: `createReport`
/// (services/reportService.ts).
Map<String, dynamic> reportCreatedJson() {
  return {
    'id': FixtureIds.report,
    'status': 'open',
    'createdAt': FixtureTimes.read,
  };
}

// ---------------------------------------------------------------------------
// Socket events (server/socket.ts)
// ---------------------------------------------------------------------------

/// `room_joined` for the city room: the view `buildRoomJoinView`
/// (services/roomService.ts) builds. A city room has no `description`, so
/// the key is left out, as JSON drops undefined values.
Map<String, dynamic> roomJoinedJson({int? lastReadAt = FixtureTimes.read}) {
  return {
    'room': {
      'id': FixtureIds.cityRoom,
      'name': _cityRoomName,
      'type': 'public',
      'cityKey': FixtureIds.city,
      'imageUrl': _cityImageUrl,
      'location': {'latitude': 44.80401, 'longitude': 20.46513},
      'participants': <String>[],
      'otherUserId': null,
    },
    ...roomMessagesPageJson(hasMore: false),
    'lastReadAt': lastReadAt,
  };
}

/// `room_joined` for a DM nobody has written in yet: `buildRoomJoinView`
/// (services/roomService.ts). Its name and photo are the other user's.
Map<String, dynamic> directRoomJoinedJson() {
  return {
    'room': {
      'id': FixtureIds.directRoom,
      'name': 'ana',
      'type': 'private',
      'cityKey': null,
      'imageUrl': _photoUrl,
      'location': null,
      'participants': [FixtureIds.me, FixtureIds.otherUser],
      'otherUserId': FixtureIds.otherUser,
    },
    'messages': <Map<String, dynamic>>[],
    'pagination': {'hasMore': false, 'nextCursor': null},
    'lastReadAt': null,
  };
}

/// The acknowledgement of a stored `send_message`.
Map<String, dynamic> sendMessageAckJson() {
  return {'ok': true, 'message': messageJson()};
}

/// `message_removed`: `MessageRemovedPayload`. `parentMessageId` is set for
/// a thread reply and null for a top-level message; `userId` is the author
/// and `createdAt` the message's own time.
Map<String, dynamic> messageRemovedJson({bool isReply = false}) {
  return {
    'messageId': isReply ? FixtureIds.reply : FixtureIds.message,
    'roomId': FixtureIds.cityRoom,
    'parentMessageId': isReply ? FixtureIds.message : null,
    'userId': isReply ? FixtureIds.me : FixtureIds.otherUser,
    'createdAt': isReply ? FixtureTimes.replied : FixtureTimes.sent,
  };
}

/// The `error` event and a refused acknowledgement's `error`:
/// `emitSocketError`.
Map<String, dynamic> socketErrorJson(String code, String message) {
  return {
    'error': {'code': code, 'message': message},
  };
}

// ---------------------------------------------------------------------------
// Push notifications
// ---------------------------------------------------------------------------

/// The FCM data of a message push: `buildDataPayload`
/// (services/pushNotificationService.ts). Every value is a string.
Map<String, dynamic> messagePushDataJson() {
  return {
    'type': 'message',
    'roomId': FixtureIds.directRoom,
    'messageId': FixtureIds.message,
    'senderId': FixtureIds.otherUser,
  };
}

/// The FCM data of a reply push: `buildDataPayload`
/// (services/pushNotificationService.ts), with the thread and the
/// recipient's Activity item.
Map<String, dynamic> replyPushDataJson() {
  return {
    'type': 'reply',
    'roomId': FixtureIds.cityRoom,
    'messageId': FixtureIds.reply,
    'senderId': FixtureIds.otherUser,
    'threadId': FixtureIds.message,
    'notificationId': FixtureIds.notification,
  };
}
