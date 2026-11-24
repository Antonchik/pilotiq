import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/progress/exam_attempt.dart';
import 'package:pilotiq/src/progress/progress_repository.dart';
import 'package:pilotiq/src/progress/question_progress.dart';

import 'helpers.dart';

/// Counting of exam answers (`unrecorded`) and the storage of moments. Run
/// with TZ=UTC, Europe/Warsaw and America/Los_Angeles.
void main() {
  late Directory dir;
  late ProgressRepository repo;
  final now = DateTime(2026, 5, 1, 12);

  setUp(() async {
    dir = await initTempHive();
    repo = ProgressRepository();
  });
  tearDown(() => disposeTempHive(dir));

  ExamAttempt attempt({List<String> unrecorded = const ['a', 'b']}) =>
      ExamAttempt(
        id: 'att',
        licence: Licence.ppla,
        subject: SubjectId.airLaw,
        startedAt: DateTime.utc(2026, 5, 1, 10),
        finishedAt: DateTime.utc(2026, 5, 1, 10, 20),
        durationSec: 1200,
        total: 2,
        correct: 1,
        passed: false,
        reason: AttemptReason.finished,
        questionIds: const ['a', 'b'],
        answers: const {'a': 0, 'b': 1},
        unrecorded: unrecorded,
      );

  test('an answer of an attempt is counted once and removed from the list '
      'in the same step', () async {
    await repo.saveAttempt(attempt());

    expect(
      await repo.recordAttemptAnswer('att', 'a', correct: true, now: now),
      isTrue,
    );
    expect(
      await repo.recordAttemptAnswer('att', 'a', correct: true, now: now),
      isFalse,
    );

    expect((await repo.progressOf(Licence.ppla, 'a'))!.seen, 1);
    expect((await repo.attempts(Licence.ppla)).single.unrecorded, ['b']);
    final day = await repo.dailyStat(now);
    expect(day.answered, 0, reason: 'exam answers do not use the daily limit');
    expect(day.examAnswered, 1);
    expect(
      (await repo.attemptsWithUnrecordedAnswers(Licence.ppla)),
      hasLength(1),
    );
  });

  test('a missing attempt writes nothing', () async {
    expect(
      await repo.recordAttemptAnswer('none', 'a', correct: true, now: now),
      isFalse,
    );
    expect(await repo.progressOf(Licence.ppla, 'a'), isNull);
  });

  test('dropUnrecordedAnswers leaves the progress alone', () async {
    await repo.saveAttempt(attempt());
    await repo.dropUnrecordedAnswers('att', ['a', 'b']);
    expect((await repo.attempts(Licence.ppla)).single.unrecorded, isEmpty);
    expect(await repo.progressOf(Licence.ppla, 'a'), isNull);
  });

  test('an old attempt record without the list reads as fully counted', () {
    final map = attempt().toMap()..remove('unrecorded');
    expect(ExamAttempt.tryFromMap(map)!.unrecorded, isEmpty);
  });

  group('moments', () {
    test('question progress stores UTC and reads old local records', () {
      final at = DateTime.utc(2026, 10, 25, 1, 40).toLocal();
      final p = QuestionProgress(qid: 'q', lastAnsweredAt: at, dueAt: at);
      final map = p.toMap();
      expect(map['lastAnsweredAt'], '2026-10-25T01:40:00.000Z');
      expect(QuestionProgress.fromMap(map).dueAt!.isAtSameMomentAs(at), isTrue);
      final old = Map<String, dynamic>.of(map)
        ..['dueAt'] = '2026-10-25T02:40:00.000';
      expect(
        QuestionProgress.fromMap(old).dueAt,
        DateTime(2026, 10, 25, 2, 40),
      );
    });

    test('an attempt keeps its instants after a round trip', () {
      final a = attempt();
      final back = ExamAttempt.tryFromMap(a.toMap())!;
      expect(back.startedAt.isAtSameMomentAs(a.startedAt), isTrue);
      expect(back.finishedAt.isAtSameMomentAs(a.finishedAt), isTrue);
    });

    test('the unfinished attempt remembers that it is closing', () {
      final u = InProgressAttempt(
        id: 'u',
        licence: Licence.ppla,
        subject: SubjectId.airLaw,
        startedAt: now,
        durationSec: 60,
        questionIds: const [],
        closing: AttemptReason.timeout,
      );
      expect(
        InProgressAttempt.tryFromMap(u.toMap())!.closing,
        AttemptReason.timeout,
      );
      expect(
        InProgressAttempt.tryFromMap(u.toMap()..['closing'] = 'legacy')!
            .closing,
        isNull,
      );
    });
  });

  test('a late exam answer does not move back a newer state of the '
      'question', () async {
    final exam = DateTime.utc(2026, 5, 1, 10, 20);
    await repo.saveAttempt(attempt(unrecorded: const ['a']));
    // The question was practised after the exam, before the late counting.
    final later = DateTime.utc(2026, 5, 3, 9);
    await repo.recordAnswer(Licence.ppla, 'a', true, later);
    await repo.recordAnswer(Licence.ppla, 'a', true, later);
    final before = (await repo.progressOf(Licence.ppla, 'a'))!;

    await repo.recordAttemptAnswer('att', 'a', correct: false, now: exam);

    final after = (await repo.progressOf(Licence.ppla, 'a'))!;
    expect(after.seen, before.seen + 1);
    expect(after.wrong, before.wrong + 1);
    expect(after.correct, before.correct);
    expect(after.box, before.box);
    expect(after.consecutiveCorrect, before.consecutiveCorrect);
    expect(after.dueAt, before.dueAt);
    expect(after.lastAnsweredAt, before.lastAnsweredAt);
    expect((await repo.attempts(Licence.ppla)).single.unrecorded, isEmpty);
  });
}
