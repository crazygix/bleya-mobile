import 'package:bleya/controllers/push_notifications_controller.dart';
import 'package:bleya/domain/entities/message.dart';
import 'package:bleya/domain/entities/room.dart';
import 'package:bleya/main.dart';
import 'package:bleya/services/socket_service.dart';
import 'package:bleya/use_cases/notification/get_notification_thread_context_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final room = Room(id: 'room-x', name: 'Belgrade');
  final openRoom = OpenRoomPushNavigationRequest(room: room);
  final openThread = OpenThreadPushNavigationRequest(
    threadContext: NotificationThreadContext(
      room: room,
      parentMessage: Message(
        id: 'thread-1',
        roomId: 'room-x',
        userId: 'user-2',
        username: 'bob',
        text: 'Coffee?',
        createdAt: DateTime(2026, 1, 1),
      ),
    ),
  );

  group('isPushForOpenChat', () {
    test('a push for the open room, with no thread open, opens nothing', () {
      expect(
        isPushForOpenChat(openRoom, const OpenChat(roomId: 'room-x')),
        isTrue,
      );
    });

    test('a push for the open thread opens nothing', () {
      expect(
        isPushForOpenChat(openThread, const OpenChat(threadId: 'thread-1')),
        isTrue,
      );
      expect(
        isPushForOpenChat(
          openThread,
          const OpenChat(roomId: 'room-x', threadId: 'thread-1'),
        ),
        isTrue,
      );
    });

    test('opens the room when a thread of it is on top', () {
      expect(
        isPushForOpenChat(
          openRoom,
          const OpenChat(roomId: 'room-x', threadId: 'thread-1'),
        ),
        isFalse,
      );
    });

    test('opens the chat when another one, or none, is open', () {
      expect(
        isPushForOpenChat(openRoom, const OpenChat(roomId: 'room-d')),
        isFalse,
      );
      expect(isPushForOpenChat(openRoom, OpenChat.none), isFalse);
      expect(
        isPushForOpenChat(openThread, const OpenChat(roomId: 'room-x')),
        isFalse,
      );
      expect(
        isPushForOpenChat(openThread, const OpenChat(threadId: 'thread-2')),
        isFalse,
      );
    });
  });
}
