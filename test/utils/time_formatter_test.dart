import 'package:bleya/utils/time_formatter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

/// The first day of [year] in the local time zone that is shorter (spring)
/// or longer (autumn) than 24 hours because of a clock change, if any.
DateTime? _clockChangeDay(int year, {required bool spring}) {
  for (var day = DateTime(year);
      day.year == year;
      day = DateTime(day.year, day.month, day.day + 1)) {
    final length = DateTime(day.year, day.month, day.day + 1).difference(day);
    if (spring ? length.inHours < 24 : length.inHours > 24) return day;
  }
  return null;
}

void main() {
  group('calendarDaysBetween', () {
    test('counts dates, not 24-hour periods', () {
      expect(
        calendarDaysBetween(
            DateTime(2026, 3, 28, 23), DateTime(2026, 3, 30, 1)),
        2,
      );
      expect(
        calendarDaysBetween(
          DateTime(2026, 3, 29, 23, 59),
          DateTime(2026, 3, 30, 0, 1),
        ),
        1,
      );
      expect(
        calendarDaysBetween(
          DateTime(2026, 3, 30, 0, 1),
          DateTime(2026, 3, 30, 23, 59),
        ),
        0,
      );
      expect(
        calendarDaysBetween(DateTime(2025, 12, 31, 12), DateTime(2026, 1, 1)),
        1,
      );
    });

    test('is negative for a later first date', () {
      expect(
        calendarDaysBetween(DateTime(2026, 3, 30), DateTime(2026, 3, 28)),
        -2,
      );
    });

    test('uses the local dates of UTC times', () {
      final from = DateTime.utc(2026, 3, 28, 23, 30);
      final to = DateTime.utc(2026, 3, 30, 0, 30);

      expect(
        calendarDaysBetween(from, to),
        calendarDaysBetween(from.toLocal(), to.toLocal()),
      );
    });
  });

  group('formatMessageDateLabel', () {
    final now = DateTime(2026, 3, 30, 9);

    test('says Today and Yesterday, then the date', () {
      expect(
        formatMessageDateLabel(DateTime(2026, 3, 30, 0, 5), now: now),
        'Today',
      );
      expect(
        formatMessageDateLabel(DateTime(2026, 3, 29, 12), now: now),
        'Yesterday',
      );
      expect(
        formatMessageDateLabel(DateTime(2026, 3, 28, 23), now: now),
        'Mar 28',
      );
    });

    test('adds the year for an earlier year', () {
      expect(
        formatMessageDateLabel(DateTime(2025, 12, 31, 18), now: now),
        'Dec 31, 2025',
      );
    });
  });

  group('formatRelativeTime', () {
    // A date with no clock change near it.
    final now = DateTime(2026, 6, 15, 12);

    test('counts minutes and hours within a day', () {
      expect(formatRelativeTime(DateTime(2026, 6, 15, 11, 59, 30), now: now),
          'now');
      expect(formatRelativeTime(DateTime(2026, 6, 15, 11, 55), now: now), '5m');
      expect(formatRelativeTime(DateTime(2026, 6, 15, 9), now: now), '3h');
      // Yesterday evening, but under a day ago.
      expect(formatRelativeTime(DateTime(2026, 6, 14, 13), now: now), '23h');
    });

    test('counts calendar days from a day ago', () {
      expect(
        formatRelativeTime(DateTime(2026, 6, 14, 11), now: now),
        'Yesterday',
      );
      // 47 hours ago, but two dates back.
      expect(formatRelativeTime(DateTime(2026, 6, 13, 13), now: now), '2d');
      expect(formatRelativeTime(DateTime(2026, 6, 9, 12), now: now), '6d');
    });

    test('counts weeks up to 30 days, then months', () {
      expect(formatRelativeTime(DateTime(2026, 6, 8, 12), now: now), '1w');
      expect(formatRelativeTime(DateTime(2026, 5, 18, 12), now: now), '4w');
      expect(formatRelativeTime(DateTime(2026, 5, 17, 12), now: now), '4w');
      expect(formatRelativeTime(DateTime(2026, 5, 16, 12), now: now), '1mo');
      expect(formatRelativeTime(DateTime(2026, 1, 15, 12), now: now), '5mo');
    });
  });

  group('around the spring clock change', () {
    // The local zone's short day, if it has clock changes.
    final short = _clockChangeDay(2026, spring: true);

    test(
      'the short day reads Yesterday the next morning, and the day before '
      'it reads its date',
      () {
        final day = short!;
        final nextMorning = DateTime(day.year, day.month, day.day + 1, 9);
        final dayBefore = DateTime(day.year, day.month, day.day - 1, 12);

        expect(
          formatMessageDateLabel(
            DateTime(day.year, day.month, day.day, 12),
            now: nextMorning,
          ),
          'Yesterday',
        );
        expect(
          formatMessageDateLabel(dayBefore, now: nextMorning),
          DateFormat.MMMd().format(dayBefore),
        );
        expect(
          formatMessageDateLabel(
            DateTime(day.year, day.month, day.day + 1, 0, 30),
            now: nextMorning,
          ),
          'Today',
        );
      },
      skip: short == null ? 'The local time zone has no clock changes' : false,
    );

    test(
      'a message from two dates back reads 2d, though only a day ago',
      () {
        final day = short!;
        final sent = DateTime(day.year, day.month, day.day - 1, 23);
        final now = DateTime(day.year, day.month, day.day + 1, 0, 30);
        expect(now.difference(sent).inHours, 24);

        expect(formatRelativeTime(sent, now: now), '2d');
      },
      skip: short == null ? 'The local time zone has no clock changes' : false,
    );
  });

  group('around the autumn clock change', () {
    // The local zone's long day, if it has clock changes.
    final long = _clockChangeDay(2026, spring: false);

    test(
      'a full day ago on the same date counts in hours',
      () {
        final day = long!;
        final sent = DateTime(day.year, day.month, day.day, 0, 10);
        final now = sent.add(const Duration(hours: 24));
        expect(calendarDaysBetween(sent, now), 0);

        expect(formatRelativeTime(sent, now: now), '24h');
        expect(formatMessageDateLabel(sent, now: now), 'Today');
      },
      skip: long == null ? 'The local time zone has no clock changes' : false,
    );
  });
}
