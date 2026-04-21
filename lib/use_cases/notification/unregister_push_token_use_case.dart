import '../../domain/repositories/notification_repository.dart';

class UnregisterPushTokenUseCase {
  final NotificationRepository _notificationRepository;

  UnregisterPushTokenUseCase(this._notificationRepository);

  Future<void> call({required String token}) async {
    await _notificationRepository.unregisterPushToken(token: token);
  }
}
