import 'package:bleya/domain/entities/notification.dart' as entity;
import 'package:bleya/widgets/notification_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

entity.Notification _reply({String? senderAvatarUrl}) {
  return entity.Notification(
    id: 'n1',
    senderId: 'user-2',
    senderName: 'bob',
    senderAvatarUrl: senderAvatarUrl,
    roomId: 'room-x',
    roomName: 'Belgrade, Serbia',
    roomType: 'city',
    messageId: 'm2',
    threadId: 'm1',
    parentMessageText: 'Coffee?',
    replyText: 'Count me in',
    previewText: 'Count me in',
    type: 'reply',
    isRead: false,
    createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
  );
}

void main() {
  Future<void> showTile(WidgetTester tester, entity.Notification reply) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationTile(notification: reply, onTap: () {}),
        ),
      ),
    );
  }

  ImageProvider? senderPhoto(WidgetTester tester) {
    return tester
        .widget<CircleAvatar>(find.byType(CircleAvatar))
        .backgroundImage;
  }

  testWidgets("shows the sender's initial when the photo URL can't be used",
      (tester) async {
    for (final url in [
      null,
      '',
      'not a url',
      'ftp://cdn.test/a.jpg',
      'https://',
    ]) {
      await showTile(tester, _reply(senderAvatarUrl: url));

      expect(senderPhoto(tester), isNull, reason: '$url');
      expect(find.text('B'), findsOneWidget, reason: '$url');
    }
  });

  testWidgets("loads the sender's photo near its display size", (tester) async {
    await showTile(
      tester,
      _reply(senderAvatarUrl: 'https://cdn.test/avatars/user-2.jpg'),
    );

    expect(
      senderPhoto(tester),
      isA<ResizeImage>()
          .having((i) => i.width, 'width', 288)
          .having((i) => i.height, 'height', 288)
          .having(
            (i) => i.imageProvider,
            'image',
            const NetworkImage('https://cdn.test/avatars/user-2.jpg'),
          ),
    );
    expect(find.text('B'), findsNothing);
  });

  testWidgets("shows the sender's initial when the photo fails to load",
      (tester) async {
    await showTile(
      tester,
      _reply(senderAvatarUrl: 'https://cdn.test/avatars/user-2.jpg'),
    );

    // Tests answer every network request with an error.
    await tester.pumpAndSettle();

    expect(senderPhoto(tester), isNull);
    expect(find.text('B'), findsOneWidget);
  });
}
