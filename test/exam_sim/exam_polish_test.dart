import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pilotiq/src/exam_sim/exam_controller.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/progress/exam_attempt.dart';

import 'exam_helpers.dart';

/// Polish package, section D: what the leave dialog and the banner promise.
void main() {
  late ExamHarness h;
  late FlakyRepository flaky;

  setUp(() async {
    flaky = FlakyRepository();
    h = ExamHarness(repository: flaky);
    await h.setUp();
  });

  tearDown(() => h.tearDown());

  Future<void> failToFinish(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('exam_finish_button')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('exam_finish_confirm')));
    await settle(tester);
    expect(find.byKey(const Key('exam_finish_error')), findsOneWidget);
  }

  testWidgets('D1: a save still running when "Finish" is pressed, then the '
      'storage refuses: the dialog does not promise the answers', (
    tester,
  ) async {
    await h.pump(tester);
    await h.open(tester);
    await h.start(tester);
    // Answer 1: its save is under way (waits at the gate) ...
    flaky.inProgressGate = Completer<void>();
    final gate = flaky.inProgressGate!;
    await tester.tap(find.byKey(const Key('answer_0')));
    await tester.pump();
    // ... answer 2 is given meanwhile ...
    await tester.tap(find.byKey(const Key('exam_next')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('answer_0')));
    await tester.pump();
    // ... and the storage goes down before "Finish".
    flaky.failInProgressAlways = true;
    flaky.failAttemptSaves = 100;
    await tester.tap(find.byKey(const Key('exam_finish_button')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('exam_finish_confirm')));
    await tester.pump(const Duration(milliseconds: 300));
    gate.complete();
    await settle(tester);
    expect(find.byKey(const Key('exam_finish_error')), findsOneWidget);

    await tester.pageBack();
    await settle(tester);

    expect(find.textContaining('latest answers will be lost'), findsOneWidget);
    expect(find.textContaining('but your answers are'), findsNothing);
  });

  testWidgets('D2: a failed periodic clock save alone does not say that the '
      'answers will be lost', (tester) async {
    await h.pump(tester);
    await h.open(tester);
    await h.start(tester);
    await tester.tap(find.byKey(const Key('answer_0')));
    await settle(tester);
    expect(find.byKey(const Key('exam_persist_error')), findsNothing);

    flaky.failInProgressAlways = true;
    for (var i = 0; i < 16; i++) {
      await h.advance(tester, const Duration(seconds: 1));
    }

    expect(find.byKey(const Key('exam_persist_error')), findsNothing);
    expect(find.byKey(const Key('exam_clock_persist_error')), findsOneWidget);
    await tester.pageBack();
    await settle(tester);
    expect(find.textContaining('will be lost'), findsNothing);
    expect(find.textContaining('The timer keeps running'), findsOneWidget);
  });

  testWidgets('D2: a failed answer save still says so', (tester) async {
    await h.pump(tester);
    await h.open(tester);
    await h.start(tester);
    flaky.failInProgressAlways = true;
    await tester.tap(find.byKey(const Key('answer_0')));
    await settle(tester);
    expect(find.byKey(const Key('exam_persist_error')), findsOneWidget);
    expect(find.byKey(const Key('exam_clock_persist_error')), findsNothing);
  });

  testWidgets('D3: an ending record without stored clock runs up to now when '
      'restored through the screen, like in the scan', (tester) async {
    final start = h.now;
    // A record of the old format: ending had begun, no clock was stored.
    final record = InProgressAttempt(
      id: 'noclock',
      licence: h.args.licence,
      subject: h.subject,
      startedAt: start,
      durationSec: 1800,
      questionIds: [for (final q in h.questions.take(12)) q.id],
      closing: AttemptReason.finished,
    ).toMap()..remove('lastSeenAt');
    await Hive.box<dynamic>('config')
        .put('inprogress_${h.args.licence.id}_${h.subject.id}', record);
    h.now = start.add(const Duration(minutes: 10));
    await h.pump(tester);
    await h.open(tester);

    final a = (await h.attempts()).single;
    expect(a.id, 'noclock');
    expect(a.durationSec, 600);
    expect(a.finishedAt, start.add(const Duration(minutes: 10)));
  });

  // D4: the exact text of the leave dialog for each of the six variants.
  for (final lang in ['en', 'pl']) {
    final local = lookupAppLocalizations(Locale(lang));

    Future<void> endingDown(
      WidgetTester tester, {
      required bool progressOk,
      required bool timeout,
    }) async {
      await h.pump(tester, locale: Locale(lang));
      await h.open(tester);
      await h.start(tester);
      flaky.failInProgressAlways = !progressOk;
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const Key('answer_0')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('exam_next')));
        await settle(tester);
      }
      flaky.failInProgressAlways = true;
      flaky.failAttemptSaves = 100;
      if (timeout) {
        await h.advance(tester, const Duration(minutes: 31));
        expect(find.byKey(const Key('exam_finish_error')), findsOneWidget);
      } else {
        await h.advance(tester, const Duration(minutes: 5));
        await failToFinish(tester);
      }
      await tester.tap(find.byType(BackButton));
      await settle(tester);
    }

    void dialogIs(WidgetTester tester, String text) {
      expect(find.byType(AlertDialog), findsOneWidget);
      final shown = tester.widget<Text>(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(text),
        ),
      );
      expect(shown.data, text);
    }

    group('D4 leave dialog texts ($lang)', () {
      for (final c in <(ExamLeave, String Function())>[
        (ExamLeave.continueSaved, () => local.examLeaveNotMarkedBody),
        (ExamLeave.continueLost, () => local.examLeaveContinueLostBody),
        (ExamLeave.timeoutSaved, () => local.examLeaveTimeoutSavedBody),
        (ExamLeave.timeoutLost, () => local.examLeaveTimeoutLostBody),
      ]) {
        final (kind, text) = c;
        testWidgets(kind.name, (tester) async {
          await endingDown(
            tester,
            progressOk:
                kind == ExamLeave.continueSaved ||
                kind == ExamLeave.timeoutSaved,
            timeout:
                kind == ExamLeave.timeoutSaved || kind == ExamLeave.timeoutLost,
          );
          dialogIs(tester, text());
        });
      }

      testWidgets('endingStored', (tester) async {
        await h.pump(tester, locale: Locale(lang));
        await h.open(tester);
        await h.start(tester);
        await tester.tap(find.byKey(const Key('answer_0')));
        await settle(tester);
        flaky.failAttemptSaves = 1;
        await failToFinish(tester);
        await tester.tap(find.byType(BackButton));
        await settle(tester);
        dialogIs(tester, local.examLeaveUnsavedResultBody);
      });

      testWidgets('resultSaved', (tester) async {
        await h.pump(tester, locale: Locale(lang));
        await h.open(tester);
        await h.start(tester);
        await tester.tap(find.byKey(const Key('answer_0')));
        await settle(tester);
        flaky.failRecordCalls.add(1);
        await failToFinish(tester);
        await tester.tap(find.byType(BackButton));
        await settle(tester);
        dialogIs(tester, local.examLeaveResultSavedBody);
      });
    });
  }
}
