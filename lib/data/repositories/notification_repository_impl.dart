import 'package:dio/dio.dart';
import '../../core/errors/api_error_mapper.dart';
import '../../domain/repositories/notification_repository.dart';

import '../models/notification_model.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final Dio _dio;

  NotificationRepositoryImpl(this._dio);

  @override
  Future<NotificationPage> fetchNotifications(
      {int? limit, String? before}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (limit != null) queryParams['limit'] = limit;
      if (before != null) queryParams['before'] = before;

      final response = await _dio.get(
        '/notifications',
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      final data = response.data as Map<String, dynamic>;
      final list = (data['notifications'] as List)
          .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
          .toList();

      return NotificationPage(
        notifications: list,
        unreadCount: data['unreadCount'] as int? ?? 0,
        nextCursor: data['nextCursor']?.toString(),
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
