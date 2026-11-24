import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/exam_sim/exam_controller.dart';
import 'package:pilotiq/src/progress/exam_attempt.dart';
import 'package:pilotiq/src/progress/providers.dart';
import 'package:pilotiq/src/purchases/fake_purchase_service.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';

import '../bank/memory_hive.dart';
import 'exam_helpers.dart';

/// The table of states of ending an exam: for every combination of
///
///  * saving the progress while answering: ok / fails,
///  * the note "being ended": ok / fails,
///  * the result (the attempt): ok / fails,
///  * counting the answers: ok / fails on the first, a middle, the last,
///  * the user: stays and presses "Retry" / leaves the screen / the app is
///    killed,
///  * the reason: the button / the time ran out,
///
/// it checks what the user is told, what is stored, what the next opening
/// does, and that in the end there is exactly one attempt with every answer
/// counted once - or the exam honestly continues. Times are the real ones.
void main() {
  const answered = 6;
  final t0 = DateTime(2026, 5, 1, 12);

  final cases =
      <_Case>[
            for (final progressOk in [true, false])
              for (final markerOk in [true, false])
                for (final result in _Result.values)
                  for (final user in _User.values)
                    for (final timeout in [false, true])
                      _Case(progressOk, markerOk, result, user, timeout),
          ]
          .where((c) => !(c.user == _User.retry && c.result == _Result.allOk))
          .toList();

  for (final c in cases) {
    test(c.name, () async {
      await openMemoryBox('config');
      addTearDown(Hive.close);
      final flaky = FlakyRepository();
      var now = t0;
      final h = ExamHarness(repository: flaky);
      final args = h.args;

      ProviderContainer open() {
        final container = ProviderContainer(
          overrides: [
            purchaseServiceProvider.overrideWithValue(
              FakePurchaseService(premium: true),
            ),
            progressRepositoryProvider.overrideWithValue(flaky),
            clockProvider.overrideWithValue(Clock(() => now)),
            randomProvider.overrideWithValue(Random(7)),
            examControllerProvider.overrideWith(() => ExamController(args)),
          ],
        );
        container.listen(examControllerProvider, (_, _) {});
        return container;
      }

      ExamState stateOf(ProviderContainer c) =>
          c.read(examControllerProvider).requireValue;

      // --- the exam -------------------------------------------------------
      var container = open();
      var ctl = container.read(examControllerProvider.notifier);
      await container.read(examControllerProvider.future);
      await ctl.start();
      final unfinished = (await flaky.loadInProgressAttempt(
        Licence.ppla,
        SubjectId.communications,
      ))!;
      final ids = unfinished.questionIds;
      flaky.failInProgressAlways = !c.progressOk;
      for (var i = 0; i < answered; i++) {
        ctl.answer(0);
        ctl.next();
      }
      expect(await ctl.flushProgress(), c.progressOk);
      expect(stateOf(container).persistFailed, !c.progressOk);

      // --- the ending -------------------------------------------------------
      flaky.failInProgressAlways = !c.markerOk;
      if (c.result != _Result.allOk) {
        if (c.result == _Result.resultFails) flaky.failAttemptSaves = 1;
        if (c.result.countingFailsAt != null) {
          flaky.failRecordCalls.add(c.result.countingFailsAt!);
        }
      }
      final clickAt = t0.add(const Duration(minutes: 5));
      if (c.timeout) {
        now = t0.add(const Duration(minutes: 31));
        ctl.syncTime();
      } else {
        now = clickAt;
        unawaited(ctl.finish());
      }
      await pumpEventQueue(times: 200);
      var state = stateOf(container);
      final stored = c.result != _Result.resultFails;
      final counted = c.result.countedAfterFirstTry(answered);

      if (c.result == _Result.allOk) {
        expect(state.phase, ExamPhase.done);
      } else {
        expect(state.phase, ExamPhase.finishing);
        expect(state.finishFailed, isTrue);
        expect(state.attemptStored, stored);
        expect(state.markerStored, c.markerOk);
        // What the dialog on leaving says matches the facts.
        expect(
          state.leave,
          stored
              ? ExamLeave.resultSaved
              : (c.markerOk
                    ? ExamLeave.endingStored
                    : ExamLeave.endingNotStored),
        );
      }
      expect((await h.attempts()).length, stored ? 1 : 0);
      final left = await h.unfinished();
      expect(left == null, stored, reason: 'record of the running exam');
      if (!stored) {
        expect(left!.closing != null, c.markerOk);
      }
      expect(await _seen(flaky, ids), counted);

      // --- what the user does --------------------------------------------------
      flaky.failInProgressAlways = false;
      if (c.user == _User.retry) {
        await ctl.retryFinish();
        await pumpEventQueue(times: 200);
        expect(stateOf(container).phase, ExamPhase.done);
        await _expectEnded(h, flaky, ids, c, t0, answers: answered);
        container.dispose();
        return;
      }
      if (c.user == _User.leave) await ctl.flushProgress();
      container.dispose();

      // --- the next opening (a minute later) ----------------------------------
      if (!c.timeout) now = clickAt.add(const Duration(minutes: 1));
      container = open();
      ctl = container.read(examControllerProvider.notifier);
      await container.read(examControllerProvider.future);
      await pumpEventQueue(times: 200);
      state = stateOf(container);

      if (stored) {
        expect(state.phase, ExamPhase.rules, reason: 'nothing to resume');
        await _expectEnded(h, flaky, ids, c, t0, answers: answered);
      } else if (c.markerOk) {
        expect(state.phase, ExamPhase.done, reason: 'ending is finished');
        await _expectEnded(h, flaky, ids, c, t0, answers: answered);
      } else if (c.timeout) {
        // Time is over: closed from what was stored (answers that could not
        // be stored are lost; the dialog said so).
        expect(state.phase, ExamPhase.done);
        await _expectEnded(
          h,
          flaky,
          ids,
          c,
          t0,
          answers: c.progressOk ? answered : 0,
        );
      } else {
        // Nothing about the ending is stored and time is left: the exam
        // honestly continues.
        expect(state.phase, ExamPhase.resume);
        expect(await h.attempts(), isEmpty);
        expect(state.answeredCount, c.progressOk ? answered : 0);
        expect(await _seen(flaky, ids), 0);
        // The time keeps running while the exam is not open: 6 minutes used.
        expect(state.clock!.remaining, const Duration(minutes: 24));
      }
      container.dispose();
    });
  }
}

Future<int> _seen(FlakyRepository repo, List<String> ids) async {
  var sum = 0;
  for (final id in ids) {
    final seen = (await repo.progressOf(Licence.ppla, id))?.seen ?? 0;
    expect(seen, lessThanOrEqualTo(1), reason: 'counted twice: $id');
    sum += seen;
  }
  return sum;
}

/// One attempt, every answer counted once, real times.
Future<void> _expectEnded(
  ExamHarness h,
  FlakyRepository repo,
  List<String> ids,
  _Case c,
  DateTime t0, {
  required int answers,
}) async {
  final attempts = await h.attempts();
  expect(attempts, hasLength(1));
  final a = attempts.single;
  expect(a.answers.values.where((v) => v != null), hasLength(answers));
  expect(a.unrecorded, isEmpty);
  expect(await _seen(repo, ids), answers);
  expect(await h.unfinished(), isNull);
  if (c.timeout) {
    expect(a.reason, AttemptReason.timeout);
    expect(a.durationSec, 1800);
    expect(
      a.finishedAt.isAtSameMomentAs(t0.add(const Duration(minutes: 30))),
      isTrue,
    );
  } else {
    expect(a.reason, AttemptReason.finished);
    expect(a.durationSec, 300);
    expect(
      a.finishedAt.isAtSameMomentAs(t0.add(const Duration(minutes: 5))),
      isTrue,
    );
  }
}

enum _User { retry, leave, kill }

enum _Result {
  allOk(null),
  resultFails(null),
  countingFailsFirst(1),
  countingFailsMiddle(3),
  countingFailsLast(6);

  const _Result(this.countingFailsAt);

  final int? countingFailsAt;

  /// Answers counted right after the first try of ending.
  int countedAfterFirstTry(int answered) => switch (this) {
    allOk => answered,
    resultFails => 0,
    _ => countingFailsAt! - 1,
  };
}

class _Case {
  const _Case(
    this.progressOk,
    this.markerOk,
    this.result,
    this.user,
    this.timeout,
  );

  final bool progressOk;
  final bool markerOk;
  final _Result result;
  final _User user;
  final bool timeout;

  String get name =>
      'progress ${progressOk ? 'ok' : 'FAILS'}, marker '
      '${markerOk ? 'ok' : 'FAILS'}, ${result.name}, ${user.name}, '
      '${timeout ? 'timeout' : 'button'}';
}
