import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/domain/dates.dart';
import 'package:pilotiq/src/domain/readiness.dart';
import 'package:pilotiq/src/domain/streak.dart';
import 'package:pilotiq/src/progress/daily_stat.dart';
import 'package:pilotiq/src/progress/exam_attempt.dart';
import 'package:pilotiq/src/progress/question_progress.dart';

/// The last moment of the local calendar day of [now]. Used as the "due"
/// horizon: the repository compares due dates with an exact time, so "due
/// today" needs the end of the local day. Built from calendar fields, so a
/// 23 or 25 hour day (daylight saving) is handled.
DateTime endOfLocalDay(DateTime now) {
  final l = now.isUtc ? now.toLocal() : now;
  return DateTime(
    l.year,
    l.month,
    l.day + 1,
  ).subtract(const Duration(milliseconds: 1));
}

/// Colour class of a readiness value.
enum ReadinessLevel {
  low,
  medium,
  high;

  /// Below [mediumFrom] red, from [highFrom] green.
  static const double mediumFrom = 0.4;
  static const double highFrom = 0.75;

  static ReadinessLevel of(double readiness) => readiness >= highFrom
      ? ReadinessLevel.high
      : readiness >= mediumFrom
      ? ReadinessLevel.medium
      : ReadinessLevel.low;
}

/// Statistics of one subject of the selected licence.
class SubjectOverview {
  const SubjectOverview({
    required this.subject,
    required this.total,
    required this.covered,
    required this.correct,
    required this.wrong,
    required this.readiness,
  });

  final SubjectId subject;
  final int total;
  final int covered;
  final int correct;
  final int wrong;

  /// Estimated chance to pass the subject exam, 0..1.
  final double readiness;

  int get answers => correct + wrong;
  double get coverage => total == 0 ? 0 : covered / total;
  double get accuracy => answers == 0 ? 0 : correct / answers;
  ReadinessLevel get level => ReadinessLevel.of(readiness);
}

/// Everything the "Today" screen shows, computed once from the stored data.
class DashboardData {
  const DashboardData({
    required this.licence,
    required this.examDaysLeft,
    required this.dailyGoal,
    required this.answeredToday,
    required this.streak,
    required this.dueToday,
    required this.subjects,
    required this.weakSubjects,
    required this.lastAttempt,
    required this.legacyAttempts,
  });

  /// Minimum number of answers in a subject to count it as "weak".
  static const int weakMinAnswers = 10;
  static const int weakCount = 3;

  final Licence licence;

  /// Calendar days until the exam; 0 = today, negative = in the past, null if
  /// no date is set.
  final int? examDaysLeft;
  final int dailyGoal;
  final int answeredToday;
  final StreakResult streak;

  /// Questions of the bank that are due until the end of today.
  final int dueToday;
  final List<SubjectOverview> subjects;
  final List<SubjectOverview> weakSubjects;

  /// Newest real simulation (migrated 1.x attempts are not included).
  final ExamAttempt? lastAttempt;

  /// Number of attempts migrated from version 1.x.
  final int legacyAttempts;

  bool get goalReached => answeredToday >= dailyGoal;
  int get goalRemaining => goalReached ? 0 : dailyGoal - answeredToday;
  double get goalFraction =>
      dailyGoal <= 0 ? 0 : (answeredToday / dailyGoal).clamp(0.0, 1.0);

  int get totalQuestions => subjects.fold(0, (s, e) => s + e.total);
  int get coveredQuestions => subjects.fold(0, (s, e) => s + e.covered);
  int get correctAnswers => subjects.fold(0, (s, e) => s + e.correct);
  int get wrongAnswers => subjects.fold(0, (s, e) => s + e.wrong);

  double get coverage =>
      totalQuestions == 0 ? 0 : coveredQuestions / totalQuestions;
  double get accuracy {
    final answers = correctAnswers + wrongAnswers;
    return answers == 0 ? 0 : correctAnswers / answers;
  }

  /// Pure computation: no clock, no storage. [bankQids] lists the question
  /// ids of every subject of the bank; [dueQids] are the ids reported as due
  /// until the end of today (ids outside the bank are ignored).
  factory DashboardData.compute({
    required Licence licence,
    required DateTime now,
    required DateTime? examDate,
    required int dailyGoal,
    required Map<SubjectId, List<String>> bankQids,
    required Map<String, QuestionProgress> progress,
    required Iterable<DailyStat> dailyStats,
    required Iterable<ExamAttempt> attempts,
    required Iterable<String> dueQids,
  }) {
    final stats = <SubjectOverview>[];
    final inBank = <String>{};
    for (final subject in SubjectId.values) {
      final qids = bankQids[subject];
      if (qids == null || qids.isEmpty) continue;
      inBank.addAll(qids);
      var covered = 0;
      var correct = 0;
      var wrong = 0;
      final recent = <List<bool>>[];
      for (final id in qids) {
        final p = progress[id];
        if (p == null || p.seen == 0) continue;
        covered++;
        correct += p.correct;
        wrong += p.wrong;
        recent.add(p.recent);
      }
      final spec = ExamSpec.forSubject(subject, licence: licence);
      stats.add(
        SubjectOverview(
          subject: subject,
          total: qids.length,
          covered: covered,
          correct: correct,
          wrong: wrong,
          readiness: ReadinessCalculator.subjectReadiness(
            recentByQuestion: recent,
            bankSize: qids.length,
            quizLength: spec.quizLength,
            passRatio: spec.passRatio,
          ),
        ),
      );
    }

    final weak =
        [
          for (final s in stats)
            if (s.answers >= weakMinAnswers) s,
        ]..sort((a, b) {
          final byAccuracy = a.accuracy.compareTo(b.accuracy);
          return byAccuracy != 0
              ? byAccuracy
              : a.subject.index.compareTo(b.subject.index);
        });

    final dayKey = DailyStat.keyFor(now);
    var answeredToday = 0;
    final all = dailyStats.toList();
    for (final s in all) {
      if (s.date == dayKey) answeredToday = s.answered;
    }

    ExamAttempt? last;
    var legacy = 0;
    for (final a in attempts) {
      if (a.licence != licence) continue;
      if (a.isLegacy) {
        legacy++;
        continue;
      }
      if (last == null || a.finishedAt.isAfter(last.finishedAt)) last = a;
    }

    return DashboardData(
      licence: licence,
      examDaysLeft: examDate == null
          ? null
          : calendarDaysBetween(now, examDate),
      dailyGoal: dailyGoal,
      answeredToday: answeredToday,
      streak: StreakCalculator.compute(all, now),
      dueToday: dueQids.where(inBank.contains).toSet().length,
      subjects: stats,
      weakSubjects: weak.take(weakCount).toList(),
      lastAttempt: last,
      legacyAttempts: legacy,
    );
  }
}
