import 'package:flutter_test/flutter_test.dart';
import 'package:pilotiq/src/domain/dates.dart';
import 'package:pilotiq/src/domain/streak.dart';
import 'package:pilotiq/src/progress/daily_stat.dart';

DailyStat _d(String date, [int answered = 1]) =>
    DailyStat(date: date, answered: answered, correct: answered);

void main() {
  final today = DateTime(2026, 6, 10, 15);

  test('empty history gives 0', () {
    final r = StreakCalculator.compute(const [], today);
    expect(r.current, 0);
    expect(r.longest, 0);
    expect(r.activeToday, isFalse);
  });

  test('today and yesterday give 2', () {
    final r = StreakCalculator.compute([
      _d('2026-06-10'),
      _d('2026-06-09'),
    ], today);
    expect(r.current, 2);
    expect(r.activeToday, isTrue);
  });

  test('a gap day before yesterday breaks the streak', () {
    final r = StreakCalculator.compute([
      _d('2026-06-10'),
      _d('2026-06-08'),
      _d('2026-06-07'),
    ], today);
    expect(r.current, 1);
    expect(r.longest, 2);
  });

  test('yesterday active, nothing today yet: streak is 1, not 0', () {
    final r = StreakCalculator.compute([_d('2026-06-09')], today);
    expect(r.current, 1);
    expect(r.activeToday, isFalse);
  });

  test('last activity the day before yesterday: streak is 0', () {
    final r = StreakCalculator.compute([_d('2026-06-08')], today);
    expect(r.current, 0);
  });

  test('days with zero answers do not count', () {
    final r = StreakCalculator.compute([
      _d('2026-06-10', 0),
      _d('2026-06-09'),
    ], today);
    expect(r.current, 1);
    expect(r.activeToday, isFalse);
  });

  test('day change at midnight: 00:05 keeps yesterday streak', () {
    final r = StreakCalculator.compute([
      _d('2026-06-09'),
      _d('2026-06-08'),
    ], DateTime(2026, 6, 10, 0, 5));
    expect(r.current, 2);
  });

  test('daylight saving change (23h day) does not break the streak', () {
    // Europe switched on 2026-03-29; calendar days stay consecutive.
    final r = StreakCalculator.compute([
      _d('2026-03-28'),
      _d('2026-03-29'),
      _d('2026-03-30'),
    ], DateTime(2026, 3, 30, 10));
    expect(r.current, 3);
  });

  test('month and year boundaries', () {
    final r = StreakCalculator.compute([
      _d('2025-12-31'),
      _d('2026-01-01'),
    ], DateTime(2026, 1, 1, 9));
    expect(r.current, 2);
  });

  test(
    'time zone change: keys are the local dates when answers were given',
    () {
      // Answered late on 06-08 in one zone and early on 06-09 in another:
      // the stored keys are simply consecutive dates.
      final r = StreakCalculator.compute([
        _d('2026-06-08'),
        _d('2026-06-09'),
      ], DateTime(2026, 6, 9, 23, 59));
      expect(r.current, 2);
    },
  );

  test('a UTC "now" is converted to the local day', () {
    final utc = DateTime.utc(2026, 6, 10, 12);
    final r = StreakCalculator.compute([_d(dateKey(utc))], utc);
    expect(r.current, 1);
    expect(r.activeToday, isTrue);
  });

  test('malformed date keys are ignored', () {
    final r = StreakCalculator.compute([
      _d('garbage'),
      _d('2026-02-30'),
    ], today);
    expect(r.current, 0);
  });

  group('dates', () {
    test('dateKey / parseDateKey roundtrip', () {
      expect(dateKey(DateTime(2026, 1, 5, 23, 59)), '2026-01-05');
      expect(parseDateKey('2026-01-05'), DateTime(2026, 1, 5));
      expect(parseDateKey('2026-13-01'), isNull);
      expect(parseDateKey(null), isNull);
    });
    test('calendarDaysBetween ignores time of day', () {
      expect(
        calendarDaysBetween(
          DateTime(2026, 5, 1, 23, 59),
          DateTime(2026, 5, 2, 0, 1),
        ),
        1,
      );
      expect(
        calendarDaysBetween(DateTime(2026, 5, 2), DateTime(2026, 5, 1)),
        -1,
      );
    });
  });
}
