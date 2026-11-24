import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pilotiq/src/exam_sim/exam_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilotiq/src/progress/exam_attempt.dart';

import 'exam_helpers.dart';

void main() {
  late ExamHarness h;
  late FlakyRepository flaky;

  setUp(() async {
    flaky = FlakyRepository();
    h = ExamHarness(repository: flaky);
    await h.setUp();
  });

  tearDown(() => h.tearDown());

  testWidgets('leaving after a failed save tries again and warns when the '
      'answers are still not stored', (tester) async {
    await h.pump(tester);
    await h.open(tester);
    await h.start(tester);
    flaky.failInProgressSaves = 2;
    await tester.tap(find.byKey(const Key('answer_0')));
    await settle(tester);
    expect(find.byKey(const Key('exam_persist_error')), findsOneWidget);

    flaky.failInProgressSaves = 1;
    await tester.pageBack();
    await settle(tester);
    expect(find.textContaining('will be lost if you leave'), findsOneWidget);
    await tester.tap(find.byKey(const Key('exam_leave_stay')));
    await settle(tester);

    // The failure is over: leaving stores the answer first and says nothing.
    await tester.pageBack();
    await settle(tester);
    expect(find.textContaining('will be lost'), findsNothing);
    expect(
      find.text(
        'The timer keeps running. You can continue from the '
        'subject screen until time runs out.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('exam_leave_confirm')));
    await settle(tester);
    expect(
      (await h.unfinished())!.answers.values.whereType<int>(),
      hasLength(1),
    );
  });

  testWidgets('leaving while the result is not stored asks first, and the '
      'exam cannot be continued afterwards', (tester) async {
    await h.pump(tester);
    await h.open(tester);
    await h.start(tester);
    await tester.tap(find.byKey(const Key('answer_0')));
    await settle(tester);
    flaky.failAttemptSaves = 1;
    await tester.tap(find.byKey(const Key('exam_finish_button')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('exam_finish_confirm')));
    await settle(tester);
    expect(find.byKey(const Key('exam_finish_error')), findsOneWidget);

    await tester.pageBack();
    await settle(tester);
    expect(find.textContaining('result is not saved yet'), findsOneWidget);
    await tester.tap(find.byKey(const Key('exam_leave_stay')));
    await settle(tester);
    expect(find.byKey(const Key('exam_finish_error')), findsOneWidget);
    await tester.pageBack();
    await settle(tester);
    await tester.tap(find.byKey(const Key('exam_leave_confirm')));
    await settle(tester);
    expect((await h.unfinished())!.closing, AttemptReason.finished);

    // Opening it again finishes it; there is no way to continue.
    await h.open(tester);
    expect(find.byKey(const Key('exam_resume')), findsNothing);
    expect(find.byKey(const Key('exam_result_percent')), findsOneWidget);
    expect(await h.attempts(), hasLength(1));
    expect(await h.unfinished(), isNull);
  });

  Future<void> failToFinish(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('exam_finish_button')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('exam_finish_confirm')));
    await settle(tester);
    expect(find.byKey(const Key('exam_finish_error')), findsOneWidget);
  }

  testWidgets('nothing about the ending is stored: the dialog says the exam '
      'can be continued, and it can', (tester) async {
    await h.pump(tester);
    await h.open(tester);
    await h.start(tester);
    await tester.tap(find.byKey(const Key('answer_0')));
    await settle(tester);
    flaky.failInProgressAlways = true;
    flaky.failAttemptSaves = 1;
    await failToFinish(tester);

    await tester.pageBack();
    await settle(tester);
    expect(
      find.textContaining('can be continued and the time keeps running'),
      findsOneWidget,
    );
    expect(find.textContaining('cannot be continued'), findsNothing);
    await tester.tap(find.byKey(const Key('exam_leave_confirm')));
    await settle(tester);

    flaky.failInProgressAlways = false;
    await h.open(tester);
    expect(find.byKey(const Key('exam_resume')), findsOneWidget);
    expect(await h.attempts(), isEmpty);
  });

  testWidgets('the result is stored, only counting failed: the dialog says '
      'so and the rest is counted later', (tester) async {
    await h.pump(tester);
    await h.open(tester);
    await h.start(tester);
    await tester.tap(find.byKey(const Key('answer_0')));
    await settle(tester);
    flaky.failRecordCalls.add(1);
    await failToFinish(tester);

    await tester.pageBack();
    await settle(tester);
    expect(find.textContaining('Your result is saved'), findsOneWidget);
    await tester.tap(find.byKey(const Key('exam_leave_confirm')));
    await settle(tester);

    await h.open(tester);
    expect(find.byKey(const Key('exam_start')), findsNothing);
    expect(await h.attempts(), hasLength(1));
    expect((await h.attempts()).single.unrecorded, isEmpty);
  });

  testWidgets('while the result is being stored (no error) "back" waits and '
      'does not scare the user', (tester) async {
    await h.pump(tester);
    await h.open(tester);
    await h.start(tester);
    await tester.tap(find.byKey(const Key('answer_0')));
    await settle(tester);
    flaky.attemptGate = Completer<void>();
    await tester.tap(find.byKey(const Key('exam_finish_button')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('exam_finish_confirm')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Saving your result…'), findsOneWidget);

    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Leave the exam?'), findsNothing);
    expect(find.text('Saving your result…'), findsOneWidget);

    flaky.attemptGate!.complete();
    await settle(tester);
    expect(find.byKey(const Key('exam_result_percent')), findsOneWidget);
  });

  testWidgets('a sweep that stored the result first: the exam does not bring '
      'the unfinished record back', (tester) async {
    await h.pump(tester);
    await h.open(tester);
    await h.start(tester);
    await tester.tap(find.byKey(const Key('answer_0')));
    await settle(tester);
    final source = (await h.unfinished())!;
    final byId = {for (final q in h.questions) q.id: q};

    // Time is over; the sweep (another run) stores and clears the attempt
    // before the screen reaches its own ending.
    h.now = h.now.add(const Duration(minutes: 31));
    await ExamFinalizer(flaky).persist(
      ExamFinalizer.buildAttempt(
        source: source,
        bank: byId,
        now: h.now,
        reason: AttemptReason.timeout,
      ),
      byId,
      h.now,
    );
    expect(await h.unfinished(), isNull);
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);

    expect(await h.unfinished(), isNull);
    expect(await h.attempts(), hasLength(1));
  });
}
