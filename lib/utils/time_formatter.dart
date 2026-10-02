import 'package:intl/intl.dart';

/// Whole calendar days from [from]'s local date to [to]'s local date: 1 from
/// any time yesterday to any time today.
///
/// Counted on UTC dates, which are always 24 hours long, so a day that is 23
/// or 25 hours long because of a clock change still counts as one day.
int calendarDaysBetween(DateTime from, DateTime to) {
  final a = from.toLocal();
  final b = to.toLocal();
  return DateTime.utc(b.year, b.month, b.day)
      .difference(DateTime.utc(a.year, a.month, a.day))
      .inDays;
}

/// How long ago [dateTime] was, as the chat list and Activity show it: 'now',
/// '5m', '3h', 'Yesterday', '4d', '2w' or '3mo'. [now] is for tests.
String formatRelativeTime(DateTime dateTime, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final difference = current.difference(dateTime);

  if (difference.inSeconds < 60) {
    return 'now';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m';
  }

  final days = calendarDaysBetween(dateTime, current);
  // Under a day, or a day long but on the same date (the long day of an
  // autumn clock change), counts in hours.
  if (difference.inHours < 24 || days < 1) {
    return '${difference.inHours}h';
  } else if (days == 1) {
    return 'Yesterday';
  } else if (days < 7) {
    return '${days}d';
  } else if (days < 30) {
    return '${days ~/ 7}w';
  } else {
    return '${days ~/ 30}mo';
  }
}

String formatAbsoluteTime(DateTime dateTime, {String? locale}) {
  final format = DateFormat.jm(locale);
  return format.format(dateTime);
}

/// The label above a day's messages: 'Today', 'Yesterday', or the date.
/// [now] is for tests.
String formatMessageDateLabel(
  DateTime dateTime, {
  String? locale,
  DateTime? now,
}) {
  final current = (now ?? DateTime.now()).toLocal();
  final date = dateTime.toLocal();
  final days = calendarDaysBetween(date, current);

  if (days == 0) {
    return 'Today';
  } else if (days == 1) {
    return 'Yesterday';
  } else {
    final format = current.year == date.year
        ? DateFormat.MMMd(locale)
        : DateFormat.yMMMd(locale);
    return format.format(date);
  }
}
