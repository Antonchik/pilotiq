import 'package:flutter_test/flutter_test.dart';
import 'package:pilotiq/src/dashboard/dashboard_data.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/progress/daily_stat.dart';
import 'package:pilotiq/src/progress/exam_attempt.dart';
import 'package:pilotiq/src/progress/question_progress.dart';

QuestionProgress _p(
  String qid, {
  int correct = 0,
  int wrong = 0,
  List<bool> recent = const [],
}) => QuestionProgress(
  qid: qid,
  seen: correct + wrong,
  correct: correct,
  wrong: wrong,
  recent: recent,
);

ExamAttempt _attempt(
  String id, {
  required DateTime finished,
  AttemptReason reason = AttemptReason.finished,
  bool passed = true,
  Licence licence = Licence.ppla,
  SubjectId subject = SubjectId.airLaw,
}) => ExamAttempt(
  id: id,
  licence: licence,
  subject: subject,
  startedAt: finished.subtract(const Duration(minutes: 30)),
  finishedAt: finished,
  durationSec: 1800,
  total: 12,
  correct: passed ? 10 : 4,
  passed: passed,
  reason: reason,
);

DashboardData _compute({
  DateTime? now,
  DateTime? examDate,
  Map<SubjectId, List<String>>? bank,
  Map<String, QuestionProgress> progress = const {},
  List<DailyStat> daily = const [],
  List<ExamAttempt> attempts = const [],
  List<String> due = const [],
  int goal = 20,
}) => DashboardData.compute(
  licence: Licence.ppla,
  now: now ?? DateTime(2026, 11, 23, 12),
  examDate: examDate,
  dailyGoal: goal,
  bankQids:
      bank ??
      {
        SubjectId.airLaw: ['a1', 'a2', 'a3', 'a4'],
        SubjectId.meteorology: ['m1', 'm2'],
      },
  progress: progress,
  dailyStats: daily,
  attempts: attempts,
  dueQids: due,
);

void main() {
  group('exam countdown uses calendar days', () {
    test('exam today is 0, in the past is negative, none is null', () {
      final now = DateTime(2026, 11, 23, 22, 30);
      expect(
        _compute(now: now, examDate: DateTime(2026, 11, 23)).examDaysLeft,
        0,
      );
      expect(
        _compute(now: now, examDate: DateTime(2026, 11, 20)).examDaysLeft,
        -3,
      );
      expect(
        _compute(now: now, examDate: DateTime(2026, 12, 3)).examDaysLeft,
        10,
      );
      expect(_compute(now: now).examDaysLeft, isNull);
    });

    test('daylight saving days (23 h and 25 h) do not shift the count', () {
      // Europe/Warsaw: 2026-03-29 has 23 hours, 2026-10-25 has 25 hours. The
      // checks hold in every time zone, they are strict in Europe/Warsaw.
      final spring = DateTime(2026, 3, 29);
      expect(
        _compute(
          now: DateTime(2026, 3, 28, 23, 30),
          examDate: spring,
        ).examDaysLeft,
        1,
      );
      expect(
        _compute(
          now: DateTime(2026, 3, 29, 0, 10),
          examDate: spring,
        ).examDaysLeft,
        0,
      );
      expect(
        _compute(
          now: DateTime(2026, 3, 29, 23, 50),
          examDate: spring,
        ).examDaysLeft,
        0,
      );
      final autumn = DateTime(2026, 10, 26);
      expect(
        _compute(
          now: DateTime(2026, 10, 24, 12),
          examDate: autumn,
        ).examDaysLeft,
        2,
      );
      expect(
        _compute(
          now: DateTime(2026, 10, 25, 23, 59),
          examDate: autumn,
        ).examDaysLeft,
        1,
      );
      expect(
        _compute(
          now: DateTime(2026, 10, 26, 0, 1),
          examDate: autumn,
        ).examDaysLeft,
        0,
      );
    });
  });

  test('endOfLocalDay is the last millisecond of the local calendar day', () {
    for (final day in [
      DateTime(2026, 11, 23, 5),
      DateTime(2026, 3, 29, 1), // 23-hour day in Europe/Warsaw
      DateTime(2026, 10, 25, 1), // 25-hour day in Europe/Warsaw
      DateTime(2026, 12, 31, 23, 59),
    ]) {
      final end = endOfLocalDay(day);
      expect(end.isBefore(day), isFalse);
      expect(
        end.add(const Duration(milliseconds: 1)),
        DateTime(day.year, day.month, day.day + 1),
      );
      expect((end.year, end.month, end.day), (day.year, day.month, day.day));
    }
  });

  group('daily goal and streak', () {
    test('answers of today count towards the goal', () {
      final data = _compute(
        daily: const [
          DailyStat(date: '2026-11-23', answered: 15, correct: 9),
          DailyStat(date: '2026-11-22', answered: 40, correct: 30),
        ],
      );
      expect(data.answeredToday, 15);
      expect(data.goalReached, isFalse);
      expect(data.goalRemaining, 5);
      expect(data.goalFraction, closeTo(0.75, 1e-9));
    });

    test('goal reached and a zero goal never divide by zero', () {
      final reached = _compute(
        daily: const [DailyStat(date: '2026-11-23', answered: 25)],
      );
      expect(reached.goalReached, isTrue);
      expect(reached.goalFraction, 1);
      expect(_compute(goal: 0).goalFraction, 0);
    });

    test('streak counts consecutive days; today may still be empty', () {
      final data = _compute(
        daily: const [
          DailyStat(date: '2026-11-22', answered: 3),
          DailyStat(date: '2026-11-21', answered: 3),
        ],
      );
      expect(data.streak.current, 2);
      expect(data.streak.activeToday, isFalse);
    });
  });

  group('statistics', () {
    test('coverage, accuracy and due questions of the bank only', () {
      final data = _compute(
        progress: {
          'a1': _p('a1', correct: 3, wrong: 1),
          'm1': _p('m1', correct: 1),
          'gone': _p('gone', correct: 9),
        },
        due: ['a1', 'gone', 'a1'],
      );
      expect(data.totalQuestions, 6);
      expect(data.coveredQuestions, 2);
      expect(data.coverage, closeTo(2 / 6, 1e-9));
      expect(data.accuracy, closeTo(4 / 5, 1e-9));
      expect(data.dueToday, 1);
    });

    test('empty data gives zeros without NaN', () {
      final data = _compute();
      expect(data.coverage, 0);
      expect(data.accuracy, 0);
      expect(data.dueToday, 0);
      for (final s in data.subjects) {
        expect(s.readiness.isNaN, isFalse);
        expect(s.readiness, inInclusiveRange(0, 1));
      }
    });

    test('subjects without questions are skipped', () {
      final data = _compute(
        bank: {
          SubjectId.airLaw: ['a1'],
        },
      );
      expect(data.subjects.map((s) => s.subject), [SubjectId.airLaw]);
    });

    test('weak subjects need 10 answers, lowest accuracy first, at most 3', () {
      final bank = {
        SubjectId.airLaw: ['a1'],
        SubjectId.meteorology: ['m1'],
        SubjectId.navigation: ['n1'],
        SubjectId.communications: ['c1'],
        SubjectId.humanPerformance: ['h1'],
      };
      final data = _compute(
        bank: bank,
        progress: {
          'a1': _p('a1', correct: 6, wrong: 4), // 60 %
          'm1': _p('m1', correct: 9, wrong: 1), // 90 %
          'n1': _p('n1', correct: 2, wrong: 8), // 20 %
          'c1': _p('c1', correct: 4, wrong: 6), // 40 %
          'h1': _p('h1', correct: 0, wrong: 9), // too few answers
        },
      );
      expect(data.weakSubjects.map((s) => s.subject), [
        SubjectId.navigation,
        SubjectId.communications,
        SubjectId.airLaw,
      ]);
    });

    test('readiness level follows the thresholds', () {
      expect(ReadinessLevel.of(0.1), ReadinessLevel.low);
      expect(ReadinessLevel.of(0.4), ReadinessLevel.medium);
      expect(ReadinessLevel.of(0.74), ReadinessLevel.medium);
      expect(ReadinessLevel.of(0.75), ReadinessLevel.high);
    });
  });

  group('simulations', () {
    test('migrated attempts are counted apart and never shown as last', () {
      final data = _compute(
        attempts: [
          _attempt(
            'l1',
            finished: DateTime.utc(1970),
            reason: AttemptReason.legacy,
          ),
          _attempt(
            'l2',
            finished: DateTime.utc(1970),
            reason: AttemptReason.legacy,
          ),
          _attempt('x', finished: DateTime(2026, 11, 1), passed: false),
          _attempt('y', finished: DateTime(2026, 11, 10)),
          _attempt(
            'other',
            finished: DateTime(2026, 11, 20),
            licence: Licence.pplh,
          ),
        ],
      );
      expect(data.legacyAttempts, 2);
      expect(data.lastAttempt?.id, 'y');
    });

    test('only migrated attempts: no last simulation', () {
      final data = _compute(
        attempts: [
          _attempt(
            'l1',
            finished: DateTime.utc(1970),
            reason: AttemptReason.legacy,
          ),
        ],
      );
      expect(data.lastAttempt, isNull);
      expect(data.legacyAttempts, 1);
    });
  });
}
