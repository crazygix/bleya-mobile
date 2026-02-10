import 'package:dio/dio.dart';
import '../../core/errors/api_error_mapper.dart';
import '../../domain/repositories/message_repository.dart';
import '../dtos/message_dto.dart';

/// Data layer implementation of MessageRepository
/// Handles all Dio/network concerns and JSON parsing
class MessageRepositoryImpl implements MessageRepository {
  final Dio _dio;

  MessageRepositoryImpl(this._dio);

  @override
  Future<ThreadData> getThread(String messageId) async {
    try {
      final response = await _dio.get('/messages/$messageId/thread');
      final data = response.data as Map<String, dynamic>;
      final parentMessage = MessageDto.fromJson(data['parentMessage']);
      final replies = (data['replies'] as List)
          .map((json) => MessageDto.fromJson(json))
          .toList();

      return ThreadData(
        parentMessage: parentMessage,
        replies: replies,
      );
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    }
  }

  @override
  Future<RoomMessagesPage> getRoomMessagesPage(
    String roomId, {
    int? before,
    int? limit,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (before != null) {
        queryParams['before'] = before.toString();
      }
      if (limit != null) {
        queryParams['limit'] = limit.toString();
      }

      final response = await _dio.get(
        '/rooms/$roomId/messages',
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      final data = response.data as Map<String, dynamic>;
      final messagesJson = data['messages'] as List<dynamic>;
      final paginationJson = data['pagination'] as Map<String, dynamic>? ?? {};

      final messages = messagesJson
          .map((json) => MessageDto.fromJson(json as Map<String, dynamic>))
          .toList();

      final hasMore = paginationJson['hasMore'] as bool? ?? false;
      final nextCursor = paginationJson['nextCursor'] as int?;

      return RoomMessagesPage(
        messages: messages,
        hasMore: hasMore,
        nextCursor: nextCursor,
      );
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    }
  }

  @override
  Future<int> markRoomAsRead(String roomId) async {
    try {
      final response = await _dio.post('/rooms/$roomId/read');
      final data = response.data as Map<String, dynamic>;
      final lastReadAt = data['lastReadAt'] as int?;
      return lastReadAt ?? DateTime.now().millisecondsSinceEpoch;
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    }
  }
}
