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
}
