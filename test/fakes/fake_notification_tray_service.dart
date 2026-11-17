import 'package:bleya/services/notification_tray_service.dart';

/// Counts how often the app clears its notifications from the lock screen,
/// instead of clearing them. [isSupported] tells the app whether the device
/// gets pushes.
class FakeNotificationTrayService extends NotificationTrayService {
  FakeNotificationTrayService({
    bool isSupported = true,
    bool showsBannersItself = true,
  }) : super(
          isSupported: isSupported,
          showsBannersItself: showsBannersItself,
        );

  int clears = 0;

  /// The chats whose notifications the app cleared, as `room/thread`.
  final List<String> clearedChats = [];

  /// The banners the app showed, by message id.
  final List<String> banners = [];

  /// What iOS would ask before showing a push, while the app answers.
  bool Function(Map<String, dynamic> data)? bannerQuestions;

  @override
  Future<void> clearAll() async {
    clears++;
  }

  @override
  Future<void> clearChat({String? roomId, String? threadId}) async {
    clearedChats.add('${roomId ?? '-'}/${threadId ?? '-'}');
  }

  @override
  Future<void> showBanner({
    required String messageId,
    required String title,
    required String body,
    DateTime? sentTime,
  }) async {
    banners.add(messageId);
  }

  @override
  void answerBannerQuestions(
    bool Function(Map<String, dynamic> data)? shouldShow,
  ) {
    bannerQuestions = shouldShow;
  }
}
