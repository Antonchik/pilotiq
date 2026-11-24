import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilotiq/src/bank/question_bank_repository.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/exam_sim/exam_controller.dart';
import 'package:pilotiq/src/exam_sim/exam_sweep.dart';
import 'package:pilotiq/src/progress/exam_attempt.dart';
import 'package:pilotiq/src/progress/providers.dart';

import '../bank/memory_hive.dart';
import 'exam_helpers.dart';

/// Every answer of an exam is added to the progress of the questions exactly
/// once, whatever fails or is interrupted on the way.
void main() {
  late ExamHarness h;
  late FlakyRepository flaky;

  setUp(() async {
    flaky = FlakyRepository();
    h = ExamHarness(repository: flaky);
    await h.setUp();
  });

  tearDown(() => h.tearDown());

  const answered = 6;

  /// Plays an exam with [answered] answers up to the confirmed finish.
  Future<InProgressAttempt> play(WidgetTester tester) async {
    await h.pump(tester);
    await h.open(tester);
    await h.start(tester);
    final saved = (await h.unfinished())!;
    for (var i = 0; i < answered; i++) {
      await tester.tap(find.byKey(const Key('answer_0')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('exam_next')));
      await settle(tester);
    }
    await tester.tap(find.byKey(const Key('exam_finish_button')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('exam_finish_confirm')));
    await settle(tester);
    return saved;
  }

  Future<List<int>> seenCounts(InProgressAttempt saved) async => [
    for (final id in saved.questionIds)
      (await h.repo.progressOf(Licence.ppla, id))?.seen ?? 0,
  ];

  for (final (name, k) in [
    ('the first', 1),
    ('a middle', 3),
    ('the last', answered),
  ]) {
    testWidgets('a failure on $name of $answered answers: retry counts '
        'every answer once', (tester) async {
      flaky.failRecordCalls.add(k);
      final saved = await play(tester);

      // Not shown as saved; the attempt is stored and knows what is left.
      expect(find.byKey(const Key('exam_finish_error')), findsOneWidget);
      expect(find.byKey(const Key('exam_result_percent')), findsNothing);
      final stored = (await h.attempts()).single;
      expect(stored.unrecorded, hasLength(answered - (k - 1)));
      expect((await seenCounts(saved)).where((n) => n == 1), hasLength(k - 1));

      await tester.tap(find.byKey(const Key('exam_retry')));
      await settle(tester);

      expect(find.byKey(const Key('exam_result_percent')), findsOneWidget);
      expect(await h.attempts(), hasLength(1));
      expect((await h.attempts()).single.unrecorded, isEmpty);
      final seen = await seenCounts(saved);
      expect(seen.where((n) => n == 1), hasLength(answered));
      expect(seen.where((n) => n > 1), isEmpty);
    });
  }

  testWidgets('the app killed in the middle of counting: the rest is added '
      'when the exam is opened, nothing twice', (tester) async {
    flaky.failRecordCalls.add(4);
    final saved = await play(tester);
    expect((await seenCounts(saved)).where((n) => n == 1), hasLength(3));

    // A new container over the same storage.
    h.repo = memoryProgressRepository();
    await h.pump(tester);
    await h.open(tester);

    final seen = await seenCounts(saved);
    expect(seen.where((n) => n == 1), hasLength(answered));
    expect(seen.where((n) => n > 1), isEmpty);
    expect(await h.attempts(), hasLength(1));
  });

  test('counting twice at the same time counts once', () async {
    flaky.failRecordCalls.add(3);
    final questions = h.questions;
    final byId = {for (final q in questions) q.id: q};
    final ids = [for (final q in questions.take(6)) q.id];
    final source = InProgressAttempt(
      id: 'x',
      licence: Licence.ppla,
      subject: SubjectId.communications,
      startedAt: DateTime(2026, 5, 1, 12),
      durationSec: 1800,
      questionIds: ids,
      answers: {for (final id in ids) id: 1},
    );
    final attempt = ExamFinalizer.buildAttempt(
      source: source,
      bank: byId,
      now: DateTime(2026, 5, 1, 12, 10),
      reason: AttemptReason.finished,
    );
    final finalizer = ExamFinalizer(flaky);
    await expectLater(
      finalizer.persist(attempt, byId, DateTime(2026, 5, 1, 12, 10)),
      throwsStateError,
    );
    final now = DateTime(2026, 5, 1, 13);
    await Future.wait([
      finalizer.completePending(Licence.ppla, byId, now),
      finalizer.completePending(Licence.ppla, byId, now),
    ]);
    await finalizer.completePending(Licence.ppla, byId, now);

    for (final id in ids) {
      expect((await flaky.progressOf(Licence.ppla, id))!.seen, 1);
    }
    expect(flaky.recorded, 6);
  });

  test('an answer of a question that left the bank is dropped, not '
      'retried for ever', () async {
    final byId = {for (final q in h.questions) q.id: q};
    final ids = [for (final q in h.questions.take(3)) q.id];
    final source = InProgressAttempt(
      id: 'y',
      licence: Licence.ppla,
      subject: SubjectId.communications,
      startedAt: DateTime(2026, 5, 1, 12),
      durationSec: 1800,
      questionIds: ids,
      answers: {for (final id in ids) id: 0},
    );
    final attempt = ExamFinalizer.buildAttempt(
      source: source,
      bank: byId,
      now: DateTime(2026, 5, 1, 12, 5),
      reason: AttemptReason.finished,
    );
    flaky.failRecordCalls.add(1);
    final finalizer = ExamFinalizer(flaky);
    await expectLater(
      finalizer.persist(attempt, byId, DateTime(2026, 5, 1, 12, 5)),
      throwsStateError,
    );

    final smaller = {ids[0]: byId[ids[0]]!};
    await finalizer.completePending(
      Licence.ppla,
      smaller,
      DateTime(2026, 5, 2),
    );

    expect((await h.attempts()).single.unrecorded, isEmpty);
    expect((await flaky.progressOf(Licence.ppla, ids[0]))!.seen, 1);
    expect(await flaky.progressOf(Licence.ppla, ids[1]), isNull);
  });

  group('sweep at the start of the app', () {
    ProviderContainer container(DateTime now) {
      final c = ProviderContainer(
        overrides: [
          progressRepositoryProvider.overrideWithValue(flaky),
          clockProvider.overrideWithValue(Clock(() => now)),
          randomProvider.overrideWithValue(Random(1)),
          questionBankRepositoryProvider.overrideWithValue(
            QuestionBankRepository(
              bundle: ExamBankBundle(),
              parser: (json, licence) async =>
                  parseBank(json, licence: licence),
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('stores an expired attempt of any licence once, counts its '
        'answers and leaves a running one alone', () async {
      final ids = [for (final q in h.questions.take(4)) q.id];
      InProgressAttempt unfinished(Licence licence, DateTime start) =>
          InProgressAttempt(
            id: 'u-${licence.id}',
            licence: licence,
            subject: SubjectId.communications,
            startedAt: start,
            durationSec: 1800,
            questionIds: ids,
            answers: {ids[0]: 0, ids[1]: 2},
          );
      await flaky.saveInProgressAttempt(
        unfinished(Licence.ppla, DateTime(2026, 5, 1, 8)),
      );
      await flaky.saveInProgressAttempt(
        unfinished(Licence.pplh, DateTime(2026, 5, 1, 12)),
      );
      final c = container(DateTime(2026, 5, 1, 12, 10));

      expect(await c.read(examSweepProvider.future), 1);
      c.invalidate(examSweepProvider);
      expect(await c.read(examSweepProvider.future), 0);

      final a = (await flaky.attempts(Licence.ppla)).single;
      expect(a.reason, AttemptReason.timeout);
      expect(a.unrecorded, isEmpty);
      expect((await flaky.progressOf(Licence.ppla, ids[0]))!.seen, 1);
      expect((await flaky.progressOf(Licence.ppla, ids[1]))!.seen, 1);
      expect(
        await flaky.loadInProgressAttempt(
          Licence.ppla,
          SubjectId.communications,
        ),
        isNull,
      );
      expect(
        await flaky.loadInProgressAttempt(
          Licence.pplh,
          SubjectId.communications,
        ),
        isNotNull,
      );
      expect(await flaky.attempts(Licence.pplh), isEmpty);
    });
  });
}
