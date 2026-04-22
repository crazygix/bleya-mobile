import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../data/dtos/push_notification_payload_dto.dart';
import '../domain/entities/push_notification_payload.dart';

class PushMessagingService {
  final FirebaseMessaging _messaging;
  Future<PushNotificationPayload?>? _initialPayloadFuture;

  PushMessagingService({FirebaseMessaging? messaging})
      : _messaging = messaging ?? FirebaseMessaging.instance;

  Future<NotificationSettings> getNotificationSettings() {
    return _messaging.getNotificationSettings();
  }

  Future<NotificationSettings> requestPermission() {
    return _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  Future<String?> getToken() {
    return _messaging.getToken();
  }

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  Stream<PushNotificationPayload> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp
          .map(_parsePayload)
          .where((payload) => payload != null)
          .cast<PushNotificationPayload>();

  Future<PushNotificationPayload?> getInitialPayload() {
    return _initialPayloadFuture ??= _messaging
        .getInitialMessage()
        .then(_parsePayload);
  }

  PushNotificationPayload? _parsePayload(RemoteMessage? message) {
    if (message == null || message.data.isEmpty) {
      return null;
    }

    try {
      return PushNotificationPayloadDto.fromJson(
        Map<String, dynamic>.from(message.data),
      );
    } on FormatException {
      return null;
    }
  }
}
