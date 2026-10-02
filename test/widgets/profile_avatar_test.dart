import 'package:bleya/widgets/profile_avatar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _photo = 'https://cdn.test/avatars/user-1.jpg';

void main() {
  group('avatarImageProvider', () {
    test('decodes at twice the pixels the avatar shows', () {
      final image = avatarImageProvider(
        _photo,
        size: 48,
        devicePixelRatio: 3,
      );

      expect(
        image,
        isA<ResizeImage>()
            .having((i) => i.width, 'width', 288)
            .having((i) => i.height, 'height', 288)
            .having((i) => i.policy, 'policy', ResizeImagePolicy.fit)
            .having((i) => i.allowUpscaling, 'allowUpscaling', isFalse)
            .having(
              (i) => i.imageProvider,
              'image',
              const NetworkImage(_photo),
            ),
      );
    });

    test('rounds up to whole pixels', () {
      final image = avatarImageProvider(
        _photo,
        size: 28,
        devicePixelRatio: 2.625,
      ) as ResizeImage;

      expect(image.width, 147);
      expect(image.height, 147);
    });
  });

  group('ProfileAvatar', () {
    Future<void> showAvatar(WidgetTester tester, String? url) async {
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: ProfileAvatar(imageUrl: url, size: 28)),
        ),
      );
    }

    ImageProvider? avatarImage(WidgetTester tester) {
      return tester
          .widget<CircleAvatar>(find.byType(CircleAvatar))
          .backgroundImage;
    }

    testWidgets('loads the photo near its display size', (tester) async {
      await showAvatar(tester, _photo);

      expect(
        avatarImage(tester),
        isA<ResizeImage>()
            .having((i) => i.width, 'width', 168)
            .having((i) => i.height, 'height', 168)
            .having(
              (i) => i.imageProvider,
              'image',
              const NetworkImage(_photo),
            ),
      );
    });

    testWidgets('shows the fallback icon when the photo fails to load',
        (tester) async {
      await showAvatar(tester, _photo);
      expect(find.byIcon(CupertinoIcons.person), findsNothing);

      // Tests answer every network request with an error.
      await tester.pumpAndSettle();

      expect(avatarImage(tester), isNull);
      expect(find.byIcon(CupertinoIcons.person), findsOneWidget);
    });

    testWidgets('shows the fallback icon without a usable photo URL',
        (tester) async {
      await showAvatar(tester, 'not a url');

      expect(avatarImage(tester), isNull);
      expect(find.byIcon(CupertinoIcons.person), findsOneWidget);
    });
  });
}
