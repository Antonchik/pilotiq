import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/progress/exam_attempt.dart';
import 'package:pilotiq/src/progress/progress_repository.dart';
import 'package:pilotiq/src/progress/user_settings.dart';

import 'helpers.dart';

void main() {
  late Directory dir;
  late ProgressRepository repo;
  final now = DateTime(2026, 5, 1, 12);

  setUp(() async {
    dir = await initTempHive();
    repo = ProgressRepository();
  });
  tearDown(() => disposeTempHive(dir));

  test('recordAnswer writes progress and daily stat in one call', () async {
    final p = await repo.recordAnswer(Licence.ppla, 'PL010-0001', true, now);
    expect(p.correct, 1);
    expect(p.box, 2);
    final stat = await repo.dailyStat(now);
    expect(stat.answered, 1);
    expect(stat.correct, 1);
    expect((await repo.progressOf(Licence.ppla, 'PL010-0001'))!.box, 2);
  });

  test('three answers in a row give daily.answered == 3', () async {
    await repo.recordAnswer(Licence.ppla, 'a', true, now);
    await repo.recordAnswer(Licence.ppla, 'b', false, now);
    await repo.recordAnswer(Licence.ppla, 'a', true, now);
    final stat = await repo.dailyStat(now);
    expect(stat.answered, 3);
    expect(stat.correct, 2);
    expect((await repo.progressOf(Licence.ppla, 'a'))!.box, 3);
  });

  test('concurrent recordAnswer calls do not lose updates', () async {
    await Future.wait([
      for (var i = 0; i < 10; i++)
        repo.recordAnswer(Licence.ppla, 'same', true, now),
    ]);
    expect((await repo.dailyStat(now)).answered, 10);
    expect((await repo.progressOf(Licence.ppla, 'same'))!.seen, 10);
  });

  test('progress is stored per licence', () async {
    await repo.recordAnswer(Licence.ppla, 'q', true, now);
    expect(await repo.progressOf(Licence.pplh, 'q'), isNull);
  });

  test('answers on different days go to different daily stats', () async {
    await repo.recordAnswer(Licence.ppla, 'q', true, now);
    await repo.recordAnswer(
      Licence.ppla,
      'q',
      true,
      now.add(const Duration(days: 1)),
    );
    final stats = await repo.dailyStats();
    expect(stats.map((s) => s.date).toSet(), {'2026-05-01', '2026-05-02'});
  });

  test('exam date caps the due date', () async {
    await repo.saveSettings(
      UserSettings(examDate: DateTime(2026, 5, 3), onboardingDone: true),
    );
    final p = await repo.recordAnswer(Licence.ppla, 'q', true, now);
    // box 2 -> 2 days, but exam in 2 days -> cap max(1, 1) = 1
    expect(p.dueAt, DateTime(2026, 5, 2, 12));
  });

  test('bookmarks toggle and survive reopening the repository', () async {
    expect(await repo.toggleBookmark(Licence.ppla, 'q'), isTrue);
    final again = ProgressRepository();
    expect((await again.bookmarks(Licence.ppla)).map((p) => p.qid), ['q']);
    expect(await again.toggleBookmark(Licence.ppla, 'q'), isFalse);
    expect(await again.bookmarks(Licence.ppla), isEmpty);
  });

  test('mistakes, due and bookmarks queries', () async {
    await repo.recordAnswer(Licence.ppla, 'wrong', false, now);
    await repo.recordAnswer(Licence.ppla, 'ok', true, now);
    await repo.toggleBookmark(Licence.ppla, 'untouched');
    expect((await repo.mistakes(Licence.ppla)).map((p) => p.qid), ['wrong']);
    // nothing is due at `now`, bookmark-only questions are never due
    expect(await repo.dueQuestions(Licence.ppla, now), isEmpty);
    final later = now.add(const Duration(days: 1));
    expect((await repo.dueQuestions(Licence.ppla, later)).map((p) => p.qid), [
      'wrong',
    ]);
    final muchLater = now.add(const Duration(days: 3));
    expect(
      (await repo.dueQuestions(Licence.ppla, muchLater)).map((p) => p.qid),
      ['wrong', 'ok'],
    );
  });

  test('mistake is cleared after two correct answers in a row', () async {
    await repo.recordAnswer(Licence.ppla, 'q', false, now);
    await repo.recordAnswer(Licence.ppla, 'q', true, now);
    expect(await repo.mistakes(Licence.ppla), hasLength(1));
    await repo.recordAnswer(Licence.ppla, 'q', true, now);
    expect(await repo.mistakes(Licence.ppla), isEmpty);
  });

  test('aggregate: coverage and accuracy', () async {
    await repo.recordAnswer(Licence.ppla, 'a', true, now);
    await repo.recordAnswer(Licence.ppla, 'a', false, now);
    await repo.recordAnswer(Licence.ppla, 'b', true, now);
    final agg = await repo.aggregate(Licence.ppla, ['a', 'b', 'c', 'd']);
    expect(agg.total, 4);
    expect(agg.covered, 2);
    expect(agg.coverage, 0.5);
    expect(agg.accuracy, closeTo(2 / 3, 1e-9));
    final empty = await repo.aggregate(Licence.ppla, const []);
    expect(empty.coverage, 0);
    expect(empty.accuracy, 0);
  });

  test('attempts: save, filter, newest first', () async {
    ExamAttempt a(
      String id,
      SubjectId s,
      int day, {
      Licence l = Licence.ppla,
    }) => ExamAttempt(
      id: id,
      licence: l,
      subject: s,
      startedAt: DateTime(2026, 1, day),
      finishedAt: DateTime(2026, 1, day, 1),
      durationSec: 60,
      total: 12,
      correct: 9,
      passed: true,
      reason: AttemptReason.finished,
    );
    await repo.saveAttempt(a('1', SubjectId.airLaw, 1));
    await repo.saveAttempt(a('2', SubjectId.airLaw, 3));
    await repo.saveAttempt(a('3', SubjectId.meteorology, 2));
    await repo.saveAttempt(a('4', SubjectId.airLaw, 4, l: Licence.pplh));
    final law = await repo.attempts(Licence.ppla, subject: SubjectId.airLaw);
    expect(law.map((x) => x.id), ['2', '1']);
    expect(await repo.attempts(Licence.ppla), hasLength(3));
    // saving the same id twice does not duplicate
    await repo.saveAttempt(a('1', SubjectId.airLaw, 1));
    expect(await repo.attempts(Licence.ppla), hasLength(3));
  });

  test('in-progress attempt save / load / clear', () async {
    final a = InProgressAttempt(
      id: 'x',
      licence: Licence.ppla,
      subject: SubjectId.airLaw,
      startedAt: now,
      durationSec: 2700,
      questionIds: const ['q1', 'q2'],
      answers: const {'q1': 1, 'q2': null},
      flagged: const ['q2'],
    );
    await repo.saveInProgressAttempt(a);
    final loaded = await ProgressRepository().loadInProgressAttempt(
      Licence.ppla,
      SubjectId.airLaw,
    );
    expect(loaded!.toMap(), a.toMap());
    expect(
      await repo.loadInProgressAttempt(Licence.ppla, SubjectId.meteorology),
      isNull,
    );
    await repo.clearInProgressAttempt(Licence.ppla, SubjectId.airLaw);
    expect(
      await repo.loadInProgressAttempt(Licence.ppla, SubjectId.airLaw),
      isNull,
    );
  });

  test('settings roundtrip leaves the legacy dark key alone', () async {
    final box = await repo.loadSettings();
    expect(box.schemaVersion, 0);
    await repo.saveSettings(
      box.copyWith(dailyGoal: 40, themeMode: AppThemeMode.light),
    );
    final s = await ProgressRepository().loadSettings();
    expect(s.dailyGoal, 40);
    expect(s.themeMode, AppThemeMode.light);
  });

  test('two repository instances do not lose concurrent updates', () async {
    final other = ProgressRepository();
    await Future.wait([
      for (var i = 0; i < 50; i++)
        (i.isEven ? repo : other).recordAnswer(Licence.ppla, 'q', true, now),
    ]);
    expect((await repo.dailyStat(now)).answered, 50);
    expect((await repo.progressOf(Licence.ppla, 'q'))!.seen, 50);
  });

  test('one damaged attempt does not break the history', () async {
    final box = await Hive.openBox<dynamic>('attempts');
    await box.put('bad1', {'id': 7, 'licence': 7});
    await box.put('bad2', {
      'id': 'x',
      'licence': 'ppla',
      'subject': 'air_law',
      'startedAt': 20260510,
      'finishedAt': 'nope',
    });
    await box.put('bad3', {
      'id': 'y',
      'licence': 'ppla',
      'subject': 'air_law',
      'startedAt': '2026-01-01T10:00:00',
      'finishedAt': '2026-01-01T11:00:00',
      'answers': {'q': 'x'},
      'topicBreakdown': {'PL010': 'oops'},
      'total': '12',
    });
    await box.put('bad4', 'not a map');
    await repo.saveAttempt(
      ExamAttempt(
        id: 'good',
        licence: Licence.ppla,
        subject: SubjectId.airLaw,
        startedAt: DateTime(2026, 2, 1),
        finishedAt: DateTime(2026, 2, 1, 1),
        durationSec: 1,
        total: 12,
        correct: 9,
        passed: true,
        reason: AttemptReason.finished,
      ),
    );
    final list = await repo.attempts(Licence.ppla);
    expect(list.map((a) => a.id), containsAll(['good', 'y']));
    expect(list.map((a) => a.id), isNot(contains('x')));
  });

  test('damaged settings fall back to defaults instead of throwing', () async {
    final box = await Hive.openBox<dynamic>('config');
    await box.putAll({
      'licence': 7,
      'examDate': 20260510,
      'dailyGoal': '20',
      'themeMode': 3,
      'reminderTime': 5,
      'schemaVersion': 'x',
    });
    final s = await repo.loadSettings();
    expect(s.licence, Licence.ppla);
    expect(s.examDate, isNull);
    expect(s.dailyGoal, 20);
    expect(s.themeMode, AppThemeMode.system);
    expect(s.schemaVersion, 0);
    // recordAnswer reads the exam date from the same settings
    await repo.recordAnswer(Licence.ppla, 'q', true, now);
  });

  test('in-progress attempt keeps the display order of answers', () async {
    final a = InProgressAttempt(
      id: 'x',
      licence: Licence.ppla,
      subject: SubjectId.airLaw,
      startedAt: now,
      durationSec: 600,
      questionIds: const ['q1'],
      answers: const {'q1': 2},
      answerOrders: const {
        'q1': [3, 0, 2, 1],
      },
    );
    await repo.saveInProgressAttempt(a);
    await Hive.close();
    Hive.init(dir.path);
    final back = await ProgressRepository().loadInProgressAttempt(
      Licence.ppla,
      SubjectId.airLaw,
    );
    expect(back!.answerOrders, {
      'q1': [3, 0, 2, 1],
    });
    expect(back.answers, {'q1': 2});
  });

  test('a damaged in-progress record is ignored', () async {
    final box = await Hive.openBox<dynamic>('config');
    await box.put('inprogress_ppla_air_law', {'id': 1, 'licence': []});
    expect(
      await repo.loadInProgressAttempt(Licence.ppla, SubjectId.airLaw),
      isNull,
    );
  });
}
