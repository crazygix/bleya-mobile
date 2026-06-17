import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/report_reason.dart';
import '../platform/app_sheet.dart';
import '../providers/use_case_providers.dart';
import '../utils/app_errors.dart';
import '../utils/app_toast.dart';

/// Shows the report-reason picker and submits a report. Reusable for reporting a
/// user, a message, or a room — pass exactly one target id.
Future<void> showReportSheet({
  required BuildContext context,
  required WidgetRef ref,
  String? reportedUserId,
  String? roomId,
  String? messageId,
}) async {
  final reason = await AppSheet.actions<ReportReason>(
    context: context,
    title: 'Report',
    message: 'Why are you reporting this?',
    actions: [
      for (final reason in ReportReason.values)
        AppSheetAction<ReportReason>(value: reason, label: reason.label),
    ],
  );

  if (reason == null || !context.mounted) {
    return;
  }

  try {
    await ref.read(createReportUseCaseProvider)(
      reportedUserId: reportedUserId,
      roomId: roomId,
      messageId: messageId,
      reason: reason,
    );
    if (context.mounted) {
      AppToast.showSuccess(context, "Thanks for the report. We'll take a look.");
    }
  } catch (e) {
    if (!context.mounted) return;
    final message = e is AppError
        ? e.getUserMessage()
        : "Couldn't send the report. Try again?";
    AppToast.showError(context, message);
  }
}
