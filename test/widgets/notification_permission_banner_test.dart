import 'package:bleya/controllers/push_notifications_controller.dart';
import 'package:bleya/providers/controller_providers.dart';
import 'package:bleya/services/push_messaging_service.dart';
import 'package:bleya/use_cases/notification/get_notification_thread_context_use_case.dart';
import 'package:bleya/use_cases/notification/mark_notification_as_read_use_case.dart';
import 'package:bleya/use_cases/notification/register_push_token_use_case.dart';
import 'package:bleya/use_cases/room/get_room_use_case.dart';
import 'package:bleya/widgets/notification_permission_banner.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _denied = NotificationSettings(
  authorizationStatus: AuthorizationStatus.denied,
  alert: AppleNotificationSetting.notSupported,
  announcement: AppleNotificationSetting.notSupported,
  badge: AppleNotificationSetting.notSupported,
  carPlay: AppleNotificationSetting.notSupported,
  lockScreen: AppleNotificationSetting.notSupported,
  notificationCenter: AppleNotificationSetting.notSupported,
  showPreviews: AppleShowPreviewSetting.notSupported,
  sound: AppleNotificationSetting.notSupported,
  timeSensitive: AppleNotificationSetting.notSupported,
  criticalAlert: AppleNotificationSetting.notSupported,
  providesAppNotificationSettings: AppleNotificationSetting.notSupported,
);

/// Android, where the user refuses every permission dialog after reading
/// it for [readingTime].
class _RefusingPushMessaging extends Fake implements PushMessagingService {
  _RefusingPushMessaging(this.advanceClock);

  final void Function(Duration readingTime) advanceClock;
  int dialogs = 0;
  bool asked = false;
  bool askedAgain = false;

  @override
  Future<NotificationSettings> getNotificationSettings() async => _denied;

  @override
  Future<NotificationSettings> requestPermission() async {
    dialogs++;
    advanceClock(const Duration(seconds: 2));
    return _denied;
  }

  @override
  Future<bool> hasRequestedPermission() async => asked;

  @override
  Future<void> markPermissionRequested() async => asked = true;

  @override
  Future<bool> hasRequestedPermissionAgain() async => askedAgain;

  @override
  Future<void> markPermissionRequestedAgain() async => askedAgain = true;
}

class _UnusedRegisterPushToken extends Fake
    implements RegisterPushTokenUseCase {}

class _UnusedGetRoom extends Fake implements GetRoomUseCase {}

class _UnusedGetThreadContext extends Fake
    implements GetNotificationThreadContextUseCase {}

class _UnusedMarkNotificationAsRead extends Fake
    implements MarkNotificationAsReadUseCase {}

void main() {
  testWidgets(
      'Android: the button shows the system dialog once more, then opens '
      'Settings', (tester) async {
    var clock = DateTime(2026, 10, 1, 9);
    var settingsOpened = 0;
    final pushMessaging = _RefusingPushMessaging((readingTime) {
      clock = clock.add(readingTime);
    });
    final controller = PushNotificationsController(
      pushMessaging,
      _UnusedRegisterPushToken(),
      _UnusedGetRoom(),
      _UnusedGetThreadContext(),
      _UnusedMarkNotificationAsRead(),
      () => 'auth-token',
      supportsPushPlatform: () => true,
      platformName: () => 'android',
      openAppSettings: () async => settingsOpened++,
      now: () => clock,
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        pushNotificationsControllerProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(
        home: Scaffold(body: NotificationPermissionBanner()),
      ),
    ));
    expect(find.text('Notifications are off'), findsNothing);

    // The chat list asks, and the user refuses.
    await controller.requestPermissionIfUndecided();
    await tester.pump();
    expect(find.text('Notifications are off'), findsOneWidget);

    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();
    expect(pushMessaging.dialogs, 2);
    expect(settingsOpened, 0);

    // Refused again: from now on the button opens Settings.
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();
    expect(pushMessaging.dialogs, 2);
    expect(settingsOpened, 1);
  });
}
