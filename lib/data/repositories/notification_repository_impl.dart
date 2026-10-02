import 'dart:async';

import 'package:dio/dio.dart';
import '../../core/errors/api_error_mapper.dart';
import '../../domain/repositories/notification_repository.dart';
import '../dtos/notification_dto.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final Dio _dio;

  NotificationRepositoryImpl(this._dio);

  static bool _isTransientNetworkError(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError;
  }

  @override
  Future<NotificationPage> fetchNotifications(
      {int? limit, String? before}) async {
    final queryParams = <String, dynamic>{};
    if (limit != null) queryParams['limit'] = limit;
    if (before != null) queryParams['before'] = before;

    DioException? lastDioError;

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await _dio.get(
          '/notifications',
          queryParameters: queryParams.isEmpty ? null : queryParams,
          options: Options(
            sendTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 45),
          ),
        );

        final data = response.data as Map<String, dynamic>;
        final list = (data['notifications'] as List)
            .map((e) => NotificationDto.fromJson(e as Map<String, dynamic>))
            .toList();

        return NotificationPage(
          notifications: list,
          unreadCount: data['unreadCount'] as int? ?? 0,
          nextCursor: data['nextCursor']?.toString(),
        );
      } on DioException catch (e) {
        lastDioError = e;
        final isLastAttempt = attempt == 1;
        if (!_isTransientNetworkError(e) || isLastAttempt) {
          break;
        }
        await Future.delayed(const Duration(milliseconds: 350));
      }
    }

    throw ApiErrorMapper.mapDioError(lastDioError!);
  }

  @override
  Future<void> registerPushToken({
    required String token,
    required String platform,
    bool badge = false,
  }) async {
    try {
      await _dio.post(
        '/notifications/push/register',
        data: {
          'token': token,
          'platform': platform,
          if (badge) 'badge': true,
        },
      );
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    }
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    try {
      await _dio.post('/notifications/$notificationId/read');
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    }
  }

  @override
  Future<void> markAllAsRead() async {
    try {
      await _dio.post('/notifications/read-all');
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    }
  }

  @override
  Future<void> dismissNotification(String notificationId) async {
    try {
      await _dio.post('/notifications/$notificationId/dismiss');
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    }
  }

  @override
  Future<void> dismissAll() async {
    try {
      await _dio.post('/notifications/dismiss-all');
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    }
  }
}
