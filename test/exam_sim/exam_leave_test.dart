import 'package:flutter/material.dart';
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
}
