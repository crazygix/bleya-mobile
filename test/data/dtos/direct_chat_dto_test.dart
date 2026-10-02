import 'package:bleya/data/dtos/direct_chat_dto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/api_fixtures.dart';

void main() {
  group('GET /rooms/direct/:otherUserId/status', () {
    test('parses an open chat', () {
      final status = DirectChatDto.statusFromJson(directChatStatusJson());

      expect(status.hasChat, isTrue);
      expect(status.roomId, FixtureIds.directRoom);
      expect(status.isBlockedByMe, isFalse);
      expect(status.isBlockedByOtherUser, isFalse);
      expect(status.isBlocked, isFalse);
      expect(status.canSendMessage, isTrue);
      expect(status.isDeletedByMe, isFalse);
    });

    test('parses a chat the other user blocked', () {
      final status = DirectChatDto.statusFromJson(
        directChatStatusJson(isBlockedByOtherUser: true),
      );

      expect(status.isBlockedByOtherUser, isTrue);
      expect(status.isBlocked, isTrue);
      expect(status.canSendMessage, isFalse);
    });

    test('without canSendMessage, either block stops sending', () {
      bool canSend(Map<String, dynamic> json) =>
          DirectChatDto.statusFromJson(json..remove('canSendMessage'))
              .canSendMessage;

      expect(canSend(directChatStatusJson()), isTrue);
      expect(canSend(directChatStatusJson(isBlockedByMe: true)), isFalse);
      expect(
        canSend(directChatStatusJson(isBlockedByOtherUser: true)),
        isFalse,
      );
    });
  });

  group('DM actions', () {
    test('parses POST /rooms/direct/:otherUserId/delete', () {
      final result = DirectChatDto.actionFromJson(deleteDirectChatJson());

      expect(result.message, 'Chat removed from your list.');
      expect(result.roomId, FixtureIds.directRoom);
      expect(result.hasChat, isTrue);
      expect(result.deleted, isTrue);
      expect(result.blocked, isFalse);
    });

    test('parses POST /rooms/direct/:otherUserId/block and /unblock', () {
      final blocked = DirectChatDto.actionFromJson(blockDirectUserJson());
      final unblocked = DirectChatDto.actionFromJson(unblockDirectUserJson());

      expect(blocked.message, 'User blocked.');
      expect(blocked.blocked, isTrue);
      expect(blocked.alreadyBlocked, isFalse);
      expect(unblocked.message, 'User unblocked.');
      expect(unblocked.blocked, isFalse);
      expect(unblocked.roomId, FixtureIds.directRoom);
    });

    test('an action without a message says Done', () {
      final result = DirectChatDto.actionFromJson(
        blockDirectUserJson()..remove('message'),
      );

      expect(result.message, 'Done');
    });
  });
}
