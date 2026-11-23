import 'package:flutter_test/flutter_test.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/domain/exam_scoring.dart';
import 'package:pilotiq/src/progress/daily_stat.dart';
import 'package:pilotiq/src/progress/exam_attempt.dart';
import 'package:pilotiq/src/progress/question_progress.dart';
import 'package:pilotiq/src/progress/user_settings.dart';

void main() {
  test('QuestionProgress map roundtrip', () {
    final p = QuestionProgress(
      qid: 'PL010-0001',
      seen: 4,
      correct: 3,
      wrong: 1,
      consecutiveCorrect: 2,
      box: 3,
      lastAnsweredAt: DateTime(2026, 1, 2, 3, 4, 5),
      dueAt: DateTime(2026, 1, 6, 3, 4, 5),
      bookmarked: true,
      recent: const [true, false, true],
    );
    expect(QuestionProgress.fromMap(p.toMap()), p);
  });

  test('QuestionProgress.fromMap tolerates missing and bad fields', () {
    final p = QuestionProgress.fromMap({'qid': 'x', 'box': 99, 'dueAt': 'bad'});
    expect(p.box, 5);
    expect(p.dueAt, isNull);
    expect(p.seen, 0);
  });

  test('DailyStat roundtrip and recorded()', () {
    final s = const DailyStat(date: '2026-01-01')
        .recorded(correct: true)
        .recorded(correct: false);
    expect(s.answered, 2);
    expect(s.correct, 1);
    expect(DailyStat.fromMap(s.toMap()), s);
    expect(DailyStat.keyFor(DateTime(2026, 7, 4, 23, 59)), '2026-07-04');
  });

  test('ExamAttempt roundtrip', () {
    final a = ExamAttempt(
      id: 'a1',
      licence: Licence.pplh,
      subject: SubjectId.meteorology,
      startedAt: DateTime(2026, 1, 1, 10),
      finishedAt: DateTime(2026, 1, 1, 10, 20),
      durationSec: 1200,
      total: 12,
      correct: 9,
      passed: true,
      questionIds: const ['q1', 'q2'],
      answers: const {'q1': 2, 'q2': null},
      flagged: const ['q2'],
      topicBreakdown: const {'PL050': TopicScore(total: 12, correct: 9)},
      reason: AttemptReason.timeout,
    );
    final b = ExamAttempt.tryFromMap(a.toMap())!;
    expect(b.toMap(), a.toMap());
    expect(b.answers, {'q1': 2, 'q2': null});
    expect(b.reason, AttemptReason.timeout);
    expect(ExamAttempt.tryFromMap({'id': 'x', 'licence': 'zzz'}), isNull);
  });

  test('InProgressAttempt remaining time derives from startedAt', () {
    final a = InProgressAttempt(
      id: 'a',
      licence: Licence.ppla,
      subject: SubjectId.airLaw,
      startedAt: DateTime(2026, 1, 1, 10),
      durationSec: 600,
      questionIds: const ['q'],
    );
    expect(
      a.remaining(DateTime(2026, 1, 1, 10, 4)),
      const Duration(minutes: 6),
    );
    expect(a.remaining(DateTime(2026, 1, 1, 11)), Duration.zero);
    expect(a.isExpired(DateTime(2026, 1, 1, 10, 10)), isTrue);
    expect(a.isExpired(DateTime(2026, 1, 1, 10, 9)), isFalse);
    final back = InProgressAttempt.tryFromMap(a.toMap())!;
    expect(back.deadline, a.deadline);
  });

  test('UserSettings defaults and roundtrip', () {
    final d = UserSettings.fromMap(const {});
    expect(d.licence, Licence.ppla);
    expect(d.dailyGoal, 20);
    expect(d.themeMode, AppThemeMode.system);
    expect(d.onboardingDone, isFalse);
    expect(d.schemaVersion, 0);
    expect(d.examDate, isNull);

    final s = UserSettings(
      licence: Licence.spl,
      questionLanguage: QuestionLanguage.en,
      examDate: DateTime(2026, 9, 1),
      dailyGoal: 40,
      reminderTime: const ReminderTime(7, 5),
      themeMode: AppThemeMode.dark,
      onboardingDone: true,
      schemaVersion: 2,
    );
    expect(UserSettings.fromMap(s.toMap()), s);
    expect(s.copyWith(clearExamDate: true).examDate, isNull);
    expect(ReminderTime.tryParse('25:00'), isNull);
    expect(ReminderTime.tryParse('7:05'), const ReminderTime(7, 5));
  });
}
