import '../../domain/repositories/notification_repository.dart';

class RegisterPushTokenUseCase {
  final NotificationRepository _notificationRepository;

  RegisterPushTokenUseCase(this._notificationRepository);

  Future<void> call({
    required String token,
    required String platform,
    bool badge = false,
  }) async {
    await _notificationRepository.registerPushToken(
      token: token,
      platform: platform,
      badge: badge,
    );
  }
}
