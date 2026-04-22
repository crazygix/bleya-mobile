import '../../domain/repositories/notification_repository.dart';

class MarkNotificationAsReadUseCase {
  final NotificationRepository _notificationRepository;

  MarkNotificationAsReadUseCase(this._notificationRepository);

  Future<void> call(String notificationId) async {
    await _notificationRepository.markAsRead(notificationId);
  }
}
