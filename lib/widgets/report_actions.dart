import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/message.dart';
import '../domain/entities/report_reason.dart';
import '../platform/app_dialog.dart';
import '../platform/app_sheet.dart';
import '../providers/block_providers.dart';
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
        // Age applies to a person (or the author of a message), not a room.
        if (reason != ReportReason.underage || roomId == null)
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
      AppToast.showSuccess(
          context, "Thanks for the report. We'll take a look.");
    }
  } catch (e) {
    if (!context.mounted) return;
    final message = e is AppError
        ? e.getUserMessage()
        : "Couldn't send the report. Try again?";
    AppToast.showError(context, message);
  }
}

enum _MessageAction { report, block }

/// The long-press actions for someone else's message, in a room or a thread:
/// report the message, or block its author. Pass the screen's [context], not
/// the message row's, which goes away when the row leaves the list.
Future<void> showMessageActions({
  required BuildContext context,
  required WidgetRef ref,
  required Message message,
}) async {
  final selected = await AppSheet.actions<_MessageAction>(
    context: context,
    actions: const [
      AppSheetAction(value: _MessageAction.report, label: 'Report message'),
      AppSheetAction(
        value: _MessageAction.block,
        label: 'Block author',
        isDestructive: true,
      ),
    ],
  );
  if (selected == null || !context.mounted) return;

  switch (selected) {
    case _MessageAction.report:
      await showReportSheet(
        context: context,
        ref: ref,
        messageId: message.id,
        reportedUserId: message.userId,
      );
    case _MessageAction.block:
      await _blockAuthor(context: context, ref: ref, userId: message.userId);
  }
}

Future<void> _blockAuthor({
  required BuildContext context,
  required WidgetRef ref,
  required String userId,
}) async {
  final confirmed = await AppDialog.confirm(
    context,
    title: 'Block user?',
    message: 'They will not be able to message you anymore.',
    confirmText: 'Block',
    destructive: true,
  );
  if (!confirmed || !context.mounted) return;

  try {
    await ref.read(blockUserUseCaseProvider)(userId);
    if (!context.mounted) return;
    recordBlockChange(ref, userId, blocked: true);
    AppToast.showInfo(context, 'User blocked.');
  } catch (e) {
    if (!context.mounted) return;
    final message = e is AppError
        ? e.getUserMessage()
        : "Couldn't block this user right now.";
    AppToast.showError(context, message);
  }
}
