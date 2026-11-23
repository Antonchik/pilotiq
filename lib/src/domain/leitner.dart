import 'package:pilotiq/src/domain/dates.dart';
import 'package:pilotiq/src/progress/question_progress.dart';

/// Leitner-lite scheduler: 5 boxes with intervals of 1/2/4/8/16 days.
/// A correct answer moves the question one box up (max 5), a wrong one back to
/// box 1. When an exam date is set, the interval is capped by half of the
/// remaining days (but at least one day).
class LeitnerScheduler {
  const LeitnerScheduler();

  static const List<int> intervalsDays = [1, 2, 4, 8, 16];
  static const int maxBox = 5;

  /// Interval in days for [box] (1..5), optionally capped by [examDate].
  /// An exam date in the past (the exam is over, the user is probably
  /// retaking it later) deliberately does not cap anything; today's date caps
  /// the interval to one day.
  int intervalDays(int box, {required DateTime now, DateTime? examDate}) {
    final base = intervalsDays[box.clamp(1, maxBox) - 1];
    if (examDate == null) return base;
    final daysLeft = calendarDaysBetween(now, examDate);
    if (daysLeft < 0) return base;
    final cap = daysLeft ~/ 2 < 1 ? 1 : daysLeft ~/ 2;
    return base < cap ? base : cap;
  }

  /// Returns [progress] updated with one answer given at [now].
  QuestionProgress answer(
    QuestionProgress progress, {
    required bool correct,
    required DateTime now,
    DateTime? examDate,
  }) {
    final box = correct
        ? (progress.box + 1 > maxBox ? maxBox : progress.box + 1)
        : 1;
    final days = intervalDays(box, now: now, examDate: examDate);
    final recent = [...progress.recent, correct];
    return progress.copyWith(
      seen: progress.seen + 1,
      correct: progress.correct + (correct ? 1 : 0),
      wrong: progress.wrong + (correct ? 0 : 1),
      consecutiveCorrect: correct ? progress.consecutiveCorrect + 1 : 0,
      box: box,
      lastAnsweredAt: now,
      dueAt: addCalendarDays(now, days),
      recent: recent.length > QuestionProgress.recentLimit
          ? recent.sublist(recent.length - QuestionProgress.recentLimit)
          : recent,
    );
  }
}
