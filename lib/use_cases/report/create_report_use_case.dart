import '../../domain/entities/report_reason.dart';
import '../../domain/repositories/report_repository.dart';

class CreateReportUseCase {
  final ReportRepository _repository;

  CreateReportUseCase(this._repository);

  Future<void> call({
    String? reportedUserId,
    String? roomId,
    String? messageId,
    required ReportReason reason,
    String? details,
  }) {
    return _repository.createReport(
      reportedUserId: reportedUserId,
      roomId: roomId,
      messageId: messageId,
      reason: reason,
      details: details,
    );
  }
}
