import '../entities/report_reason.dart';

/// Domain repository interface for reporting users, messages, or rooms.
abstract class ReportRepository {
  Future<void> createReport({
    String? reportedUserId,
    String? roomId,
    String? messageId,
    required ReportReason reason,
    String? details,
  });
}
