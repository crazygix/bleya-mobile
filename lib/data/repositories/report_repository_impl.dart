import 'package:dio/dio.dart';
import '../../core/errors/api_error_mapper.dart';
import '../../domain/entities/report_reason.dart';
import '../../domain/repositories/report_repository.dart';

/// Data layer implementation of ReportRepository (POST /reports).
class ReportRepositoryImpl implements ReportRepository {
  final Dio _dio;

  ReportRepositoryImpl(this._dio);

  @override
  Future<void> createReport({
    String? reportedUserId,
    String? roomId,
    String? messageId,
    required ReportReason reason,
    String? details,
  }) async {
    try {
      await _dio.post(
        '/reports',
        data: {
          if (reportedUserId != null) 'reportedUserId': reportedUserId,
          if (roomId != null) 'roomId': roomId,
          if (messageId != null) 'messageId': messageId,
          'reason': reason.apiValue,
          if (details != null && details.isNotEmpty) 'details': details,
        },
      );
    } on DioException catch (e) {
      throw ApiErrorMapper.mapDioError(e);
    }
  }
}
