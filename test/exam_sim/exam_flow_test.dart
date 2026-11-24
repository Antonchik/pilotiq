import 'package:pilotiq/src/domain/dates.dart';
import 'package:pilotiq/src/domain/streak.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/progress/exam_attempt.dart';
import 'package:pilotiq/src/purchases/paywall_launcher.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';

import 'exam_helpers.dart';

void main() {
  late ExamHarness h;

  setUp(() async {
    h = ExamHarness();
    await h.setUp();
  });

  tearDown(() => h.tearDown());

  Future<void> answerAndNext(WidgetTester tester, {int position = 0}) async {
    await tester.tap(find.byKey(Key('answer_$position')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('exam_next')));
    await settle(tester);
  }

  /// Answers [count] questions (the first position) and ends on the next one.
  Future<void> answerFirst(WidgetTester tester, int count) async {
    for (var i = 0; i < count; i++) {
      await answerAndNext(tester);
    }
  }

  Future<void> finishWithDialog(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('exam_finish_button')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('exam_finish_confirm')));
    await settle(tester);
  }

  group('rules and the exam', () {
    testWidgets('rules show the number of questions, time and pass mark', (
      tester,
    ) async {
      await h.pump(tester);
      await h.open(tester);

      expect(find.text('12 questions'), findsOneWidget);
      expect(find.text('Time limit: 30 minutes'), findsOneWidget);
      expect(find.textContaining('Pass mark: 75%'), findsOneWidget);
      expect(await h.unfinished(), isNull);
    });

    testWidgets('a fresh sample of 12 questions; answers are not '
        'highlighted', (tester) async {
      await h.pump(tester);
      await h.open(tester);
      await h.start(tester);

      expect(find.text('Question 1 of 12'), findsOneWidget);
      await tester.tap(find.byKey(const Key('answer_0')));
      await settle(tester);

      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.byIcon(Icons.cancel), findsNothing);
      expect(find.text('Correct!'), findsNothing);
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(3));
      final saved = (await h.unfinished())!;
      expect(saved.questionIds, hasLength(12));
      expect(saved.questionIds.toSet(), hasLength(12));
      expect(saved.answerOrders, hasLength(12));
    });

    testWidgets('changing an answer on question 3 keeps the last choice', (
      tester,
    ) async {
      await h.pump(tester);
      await h.open(tester);
      await h.start(tester);
      await tester.tap(find.byKey(const Key('exam_next')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('exam_next')));
      await settle(tester);
      expect(find.text('Question 3 of 12'), findsOneWidget);

      await tester.tap(find.byKey(const Key('answer_0')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('answer_2')));
      await settle(tester);

      final saved = (await h.unfinished())!;
      final qid = saved.questionIds[2];
      expect(saved.answers[qid], saved.answerOrders[qid]![2]);
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(find.text('1 answered'), findsOneWidget);
    });

    testWidgets('a marked question shows in the grid and jumping works', (
      tester,
    ) async {
      await h.pump(tester);
      await h.open(tester);
      await h.start(tester);
      await tester.tap(find.byKey(const Key('exam_flag')));
      await settle(tester);
      expect(find.text('Marked: tap to unmark'), findsOneWidget);
      await tester.tap(find.byKey(const Key('exam_next')));
      await settle(tester);

      await tester.tap(find.byKey(const Key('exam_grid_button')));
      await settle(tester);
      expect(
        find.descendant(
          of: find.byKey(const Key('grid_cell_0')),
          matching: find.byIcon(Icons.flag),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('grid_cell_1')),
          matching: find.byIcon(Icons.flag),
        ),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('grid_cell_5')));
      await settle(tester);

      expect(find.text('Question 6 of 12'), findsOneWidget);
      expect((await h.unfinished())!.flagged, hasLength(1));
    });

    testWidgets('finishing with 2 unanswered warns with the number 2, and '
        'a double tap stores one attempt', (tester) async {
      await h.pump(tester);
      await h.open(tester);
      await h.start(tester);
      await answerFirst(tester, 10);

      await tester.tap(find.byKey(const Key('exam_finish_button')));
      await settle(tester);
      expect(find.text('2 questions are not answered.'), findsOneWidget);
      expect(find.text('No questions are marked.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('exam_finish_cancel')));
      await settle(tester);
      expect(find.byKey(const Key('exam_position')), findsOneWidget);

      await tester.tap(find.byKey(const Key('exam_finish_button')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('exam_finish_confirm')));
      await tester.tap(
        find.byKey(const Key('exam_finish_confirm')),
        warnIfMissed: false,
      );
      await settle(tester);

      final attempts = await h.attempts();
      expect(attempts, hasLength(1));
      final a = attempts.single;
      expect(a.reason, AttemptReason.finished);
      expect(a.total, 12);
      expect(a.answers.values.where((v) => v != null), hasLength(10));
      // Unanswered count as wrong: 2 of 12 can never reach the pass mark.
      expect(a.correct, lessThanOrEqualTo(10));
      expect(find.byKey(const Key('exam_result_percent')), findsOneWidget);
      expect(await h.unfinished(), isNull);
      // A rebuild does not store anything more.
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(await h.attempts(), hasLength(1));
    });

    testWidgets('the exam passes at 75% of all questions and every answer '
        'goes to the progress once', (tester) async {
      await h.pump(tester);
      await h.open(tester);
      await h.start(tester);
      final saved = (await h.unfinished())!;
      // Answer 9 of 12 correctly: the correct answer is the one with text
      // "ok n"; find it by its text.
      for (var i = 0; i < 12; i++) {
        if (i < 9) {
          await tester.tap(find.textContaining('ok '));
        } else if (i < 11) {
          await tester.tap(find.textContaining('bad1 '));
        }
        await tester.pump();
        if (i < 11) {
          await tester.tap(find.byKey(const Key('exam_next')));
          await settle(tester);
        }
      }
      await tester.tap(find.byKey(const Key('exam_finish_inline')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('exam_finish_confirm')));
      await settle(tester);

      final a = (await h.attempts()).single;
      expect(a.correct, 9);
      expect(a.passed, isTrue);
      expect(find.text('PASSED'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      var recorded = 0;
      for (final id in saved.questionIds) {
        final p = await h.repo.progressOf(Licence.ppla, id);
        if (p != null) {
          expect(p.seen, 1);
          recorded++;
        }
      }
      expect(recorded, 11);

      // the free daily learning limit is not used up by the simulation, but
      // the day counts as active
      final days = await h.repo.dailyStats();
      expect(days.fold<int>(0, (n, d) => n + d.answered), 0);
      expect(days.fold<int>(0, (n, d) => n + d.examAnswered), 11);
      expect(days.fold<int>(0, (n, d) => n + d.examCorrect), 9);
      expect(
        StreakCalculator.compute(
          days,
          days.first.date.isEmpty
              ? DateTime.now()
              : parseDateKey(days.first.date)!,
        ).current,
        1,
      );
    });

    testWidgets('8 of 12 does not pass', (tester) async {
      await h.pump(tester);
      await h.open(tester);
      await h.start(tester);
      for (var i = 0; i < 12; i++) {
        await tester.tap(find.textContaining(i < 8 ? 'ok ' : 'bad2 '));
        await tester.pump();
        if (i < 11) {
          await tester.tap(find.byKey(const Key('exam_next')));
          await settle(tester);
        }
      }
      await tester.tap(find.byKey(const Key('exam_finish_inline')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('exam_finish_confirm')));
      await settle(tester);

      expect((await h.attempts()).single.passed, isFalse);
      expect(find.text('NOT PASSED'), findsOneWidget);
    });
  });

  group('time', () {
    testWidgets('the clock shows the time left and does not run after the '
        'screen is left', (tester) async {
      await h.pump(tester);
      await h.open(tester);
      await h.start(tester);
      expect(find.text('30:00'), findsOneWidget);

      await h.advance(tester, const Duration(minutes: 10, seconds: 5));
      expect(find.text('19:55'), findsOneWidget);

      // Leave: the exam keeps running in the store, not in a timer.
      await tester.pageBack();
      await settle(tester);
      await tester.tap(find.byKey(const Key('exam_leave_confirm')));
      await settle(tester);
      expect(find.byKey(const Key('open_exam')), findsOneWidget);
      await h.advance(tester, const Duration(hours: 2));
      expect(await h.attempts(), isEmpty);
      expect(await h.unfinished(), isNotNull);
    });

    testWidgets('time running out ends the exam and stores the attempt', (
      tester,
    ) async {
      await h.pump(tester);
      await h.open(tester);
      await h.start(tester);
      await answerFirst(tester, 3);

      await h.advance(tester, const Duration(minutes: 31));

      final a = (await h.attempts()).single;
      expect(a.reason, AttemptReason.timeout);
      expect(a.answers.values.where((v) => v != null), hasLength(3));
      expect(a.durationSec, 30 * 60);
      expect(find.byKey(const Key('exam_result_notice')), findsOneWidget);
      expect(find.textContaining('Time is up'), findsOneWidget);
      expect(await h.unfinished(), isNull);
    });

    testWidgets('time running out while the finish dialog is open closes it '
        'and stores one attempt', (tester) async {
      await h.pump(tester);
      await h.open(tester);
      await h.start(tester);
      await tester.tap(find.byKey(const Key('exam_finish_button')));
      await settle(tester);

      await h.advance(tester, const Duration(minutes: 31));

      expect(find.byKey(const Key('exam_finish_confirm')), findsNothing);
      expect(await h.attempts(), hasLength(1));
    });

    testWidgets('the app coming back after a long time ends the exam', (
      tester,
    ) async {
      await h.pump(tester);
      await h.open(tester);
      await h.start(tester);
      h.now = h.now.add(const Duration(hours: 1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);

      expect((await h.attempts()).single.reason, AttemptReason.timeout);
    });
  });

  group('restoring', () {
    testWidgets('an unfinished attempt is offered and continues with the '
        'same answers, order and time', (tester) async {
      await h.pump(tester);
      await h.open(tester);
      await h.start(tester);
      await answerFirst(tester, 2);
      final before = (await h.unfinished())!;
      final firstQid = before.questionIds.first;
      // Answer 1 was position 0 of the shuffled layout.
      final chosen = before.answers[firstQid];
      await h.advance(tester, const Duration(minutes: 10));
      await tester.pageBack();
      await settle(tester);
      await tester.tap(find.byKey(const Key('exam_leave_confirm')));
      await settle(tester);

      // A new screen (and a new controller) later.
      await h.advance(tester, const Duration(minutes: 5));
      await h.open(tester);
      expect(find.text('Unfinished exam'), findsOneWidget);
      expect(
        find.textContaining('2 of 12 answered, 15 minutes left'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('exam_start')), findsNothing);
      await tester.tap(find.byKey(const Key('exam_resume')));
      await settle(tester);

      expect(find.text('15:00'), findsOneWidget);
      expect(find.text('2 answered'), findsOneWidget);
      await tester.tap(find.byKey(const Key('exam_prev')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('exam_prev')));
      await settle(tester);
      final after = (await h.unfinished())!;
      expect(after.answerOrders, before.answerOrders);
      expect(after.answers[firstQid], chosen);
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    });

    testWidgets('"finish now" of an unfinished attempt stores it', (
      tester,
    ) async {
      await h.pump(tester);
      await h.open(tester);
      await h.start(tester);
      await answerFirst(tester, 2);
      await tester.pageBack();
      await settle(tester);
      await tester.tap(find.byKey(const Key('exam_leave_confirm')));
      await settle(tester);

      await h.open(tester);
      await tester.tap(find.byKey(const Key('exam_resume_finish')));
      await settle(tester);

      final a = (await h.attempts()).single;
      expect(a.reason, AttemptReason.finished);
      expect(await h.unfinished(), isNull);
    });

    testWidgets('an attempt that expired while the app was closed is stored '
        'when the exam is opened', (tester) async {
      await h.pump(tester);
      await h.open(tester);
      await h.start(tester);
      await answerFirst(tester, 4);
      await tester.pageBack();
      await settle(tester);
      await tester.tap(find.byKey(const Key('exam_leave_confirm')));
      await settle(tester);
      h.now = h.now.add(const Duration(hours: 3));

      await h.open(tester);

      final a = (await h.attempts()).single;
      expect(a.reason, AttemptReason.timeout);
      expect(a.answers.values.where((v) => v != null), hasLength(4));
      expect(find.byKey(const Key('exam_result_notice')), findsOneWidget);
      expect(
        find.textContaining('while the exam was not open'),
        findsOneWidget,
      );
      expect(await h.unfinished(), isNull);
    });
  });

  group('access', () {
    testWidgets('a free user gets a second simulation of the subject only '
        'through the paywall', (tester) async {
      await h.pump(tester);
      await h.open(tester);
      await h.start(tester);
      await finishWithDialog(tester);
      expect(await h.attempts(), hasLength(1));
      await tester.tap(find.byKey(const Key('exam_result_back')));
      await settle(tester);

      await h.open(tester);

      expect(h.paywalls, [PaywallTrigger.examLimit]);
      expect(find.text('Free simulation used'), findsOneWidget);
      expect(find.byKey(const Key('exam_start')), findsNothing);
    });

    testWidgets('legacy attempts and unfinished ones do not use up the free '
        'simulation', (tester) async {
      await h.seedAttempt(reason: AttemptReason.legacy);
      await h.pump(tester);
      await h.open(tester);

      expect(find.byKey(const Key('exam_start')), findsOneWidget);
      expect(h.paywalls, isEmpty);
    });

    testWidgets('Premium has no limit', (tester) async {
      await h.seedAttempt();
      await h.seedAttempt(id: 'old2');
      await h.pump(tester, premium: true);
      await h.open(tester);

      expect(find.byKey(const Key('exam_start')), findsOneWidget);
    });

    testWidgets('buying Premium on the limit screen unlocks the start', (
      tester,
    ) async {
      await h.seedAttempt();
      await h.pump(tester);
      await h.open(tester);
      expect(find.byKey(const Key('exam_start')), findsNothing);

      h.service.setEntitlement(const EntitlementState(isPremium: true));
      await settle(tester);

      expect(find.byKey(const Key('exam_start')), findsOneWidget);
    });

    testWidgets('a free result shows a teaser, Premium shows the topics', (
      tester,
    ) async {
      await h.pump(tester);
      await h.open(tester);
      await h.start(tester);
      await finishWithDialog(tester);

      expect(find.byKey(const Key('exam_result_teaser')), findsOneWidget);
      expect(find.byKey(const Key('exam_review')), findsNothing);
      expect(find.text('Results by topic'), findsNothing);
      await tester.tap(find.byKey(const Key('exam_teaser_premium')));
      await tester.pump();
      expect(h.paywalls, [PaywallTrigger.examResults]);
    });

    testWidgets('a Premium result shows the topic breakdown', (tester) async {
      await h.pump(tester, premium: true);
      await h.open(tester);
      await h.start(tester);
      await finishWithDialog(tester);

      expect(find.byKey(const Key('exam_result_teaser')), findsNothing);
      expect(find.text('Results by topic'), findsOneWidget);
      expect(find.textContaining('PL090: 0 of 12 (0%)'), findsOneWidget);
    });
  });

  group('failures', () {
    testWidgets('a result that cannot be saved is not shown as saved and '
        'can be retried', (tester) async {
      final flaky = FlakyRepository()..failAttemptSaves = 1;
      h = ExamHarness(repository: flaky);
      await h.setUp();
      await h.pump(tester);
      await h.open(tester);
      await h.start(tester);
      await answerFirst(tester, 2);

      await finishWithDialog(tester);

      expect(find.byKey(const Key('exam_finish_error')), findsOneWidget);
      expect(find.byKey(const Key('exam_result_percent')), findsNothing);
      expect(await h.attempts(), isEmpty);
      expect(await h.unfinished(), isNotNull);
      await tester.tap(find.byKey(const Key('exam_retry')));
      await settle(tester);

      expect(find.byKey(const Key('exam_result_percent')), findsOneWidget);
      expect(await h.attempts(), hasLength(1));
      expect(flaky.attemptSaves, 1);
      expect(flaky.recorded, 2);
      expect(await h.unfinished(), isNull);
    });

    testWidgets('an exam that cannot be stored does not start', (tester) async {
      final flaky = FlakyRepository()..failInProgressSaves = 1;
      h = ExamHarness(repository: flaky);
      await h.setUp();
      await h.pump(tester);
      await h.open(tester);

      await h.start(tester);
      expect(find.byKey(const Key('exam_start_error')), findsOneWidget);
      expect(find.byKey(const Key('exam_position')), findsNothing);

      await tester.tap(find.byKey(const Key('exam_retry')));
      await settle(tester);
      expect(find.byKey(const Key('exam_position')), findsOneWidget);
    });

    testWidgets('a failed save of the progress is shown and can be retried', (
      tester,
    ) async {
      final flaky = FlakyRepository();
      h = ExamHarness(repository: flaky);
      await h.setUp();
      await h.pump(tester);
      await h.open(tester);
      await h.start(tester);

      flaky.failInProgressSaves = 1;
      await tester.tap(find.byKey(const Key('answer_0')));
      await settle(tester);
      expect(find.byKey(const Key('exam_persist_error')), findsOneWidget);

      await tester.tap(find.byKey(const Key('exam_retry')));
      await settle(tester);
      expect(find.byKey(const Key('exam_persist_error')), findsNothing);
      expect(
        (await h.unfinished())!.answers.values.whereType<int>(),
        hasLength(1),
      );
    });
  });
}
