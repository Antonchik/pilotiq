import 'package:pilotiq/src/domain/dates.dart';
import 'package:pilotiq/src/progress/daily_stat.dart';

class StreakResult {
  const StreakResult({
    required this.current,
    required this.longest,
    required this.activeToday,
  });

  final int current;
  final int longest;
  final bool activeToday;
}

/// Day streaks from [DailyStat]s. A day is active if at least one question was
/// answered in it. Days are local calendar dates (the key recorded when the
/// answer was given), so a time-zone change never splits or merges a day.
/// If today has no activity yet the streak is not broken until the day ends.
class StreakCalculator {
  const StreakCalculator._();

  static StreakResult compute(Iterable<DailyStat> stats, DateTime now) {
    final days = <int>{};
    for (final s in stats) {
      if (s.answered <= 0) continue;
      final d = parseDateKey(s.date);
      if (d != null) days.add(epochDay(d));
    }
    final today = epochDay(now);
    final activeToday = days.contains(today);

    var cursor = activeToday ? today : today - 1;
    var current = 0;
    while (days.contains(cursor)) {
      current++;
      cursor--;
    }

    final sorted = days.toList()..sort();
    var longest = 0;
    var run = 0;
    int? prev;
    for (final d in sorted) {
      run = (prev != null && d == prev + 1) ? run + 1 : 1;
      if (run > longest) longest = run;
      prev = d;
    }
    return StreakResult(
        current: current, longest: longest, activeToday: activeToday);
  }
}
