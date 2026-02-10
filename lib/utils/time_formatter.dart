import 'package:intl/intl.dart';

String formatRelativeTime(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inSeconds < 60) {
    return 'now';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m';
  } else if (difference.inHours < 24) {
    return '${difference.inHours}h';
  } else if (difference.inDays == 1) {
    return 'Yesterday';
  } else if (difference.inDays < 7) {
    return '${difference.inDays}d';
  } else {
    final weeks = (difference.inDays / 7).floor();
    if (weeks < 4) {
      return '${weeks}w';
    } else {
      final months = (difference.inDays / 30).floor();
      return '${months}mo';
    }
  }
}

String formatAbsoluteTime(DateTime dateTime, {String? locale}) {
  final format = DateFormat.jm(locale);
  return format.format(dateTime);
}

String formatMessageDateLabel(DateTime dateTime, {String? locale}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(dateTime.year, dateTime.month, dateTime.day);
  final difference = today.difference(target).inDays;

  if (difference == 0) {
    return 'Today';
  } else if (difference == 1) {
    return 'Yesterday';
  } else {
    final format = now.year == dateTime.year
        ? DateFormat.MMMd(locale)
        : DateFormat.yMMMd(locale);
    return format.format(dateTime);
  }
}
