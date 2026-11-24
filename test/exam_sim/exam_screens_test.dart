import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:pilotiq/src/exam_sim/exam_sweep.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/exam_sim/exam_history_screen.dart';
import 'package:pilotiq/src/progress/exam_attempt.dart';
import 'package:pilotiq/src/purchases/paywall_launcher.dart';
import 'package:pilotiq/src/quiz/quiz_list.dart';
import 'package:pilotiq/src/subjects/subject_info.dart';

import 'exam_helpers.dart';

void main() {
  late ExamHarness h;

  setUp(() async {
    h = ExamHarness();
    await h.setUp();
  });

  tearDown(() => h.tearDown());

  Future<void> seedReviewable() => h.repo.saveAttempt(
    ExamAttempt(
      id: 'review',
      licence: Licence.ppla,
      subject: SubjectId.communications,
      startedAt: DateTime(2026, 4, 2, 9),
      finishedAt: DateTime(2026, 4, 2, 9, 20),
      durationSec: 1200,
      total: 2,
      correct: 1,
      passed: false,
      reason: AttemptReason.finished,
      questionIds: const ['PL090-0001', 'PL090-0002', 'PL090-9999'],
      answers: const {'PL090-0001': 1, 'PL090-0002': 0, 'PL090-9999': 0},
      flagged: const ['PL090-0001'],
    ),
  );

  group('history', () {
    testWidgets('lists attempts newest first, legacy ones without a date, '
        'and survives a damaged record', (tester) async {
      await h.seedAttempt(
        id: 'a',
        startedAt: DateTime(2026, 3, 1, 8),
        correct: 12,
      );
      await h.seedAttempt(
        id: 'b',
        startedAt: DateTime(2026, 4, 5, 8),
        correct: 6,
      );
      await h.seedAttempt(
        id: 'legacy',
        reason: AttemptReason.legacy,
        startedAt: DateTime.fromMillisecondsSinceEpoch(0),
        correct: 9,
      );
      await Hive.box<dynamic>('attempts').put('bad', {'id': 5, 'licence': 3});
      await Hive.box<dynamic>('attempts').put('bad2', 'text');
      await h.pump(tester, home: ExamHistoryScreen(args: h.args));

      expect(find.byKey(const ValueKey('history_a')), findsOneWidget);
      expect(find.byKey(const ValueKey('history_b')), findsOneWidget);
      final bTop = tester
          .getTopLeft(find.byKey(const ValueKey('history_b')))
          .dy;
      final aTop = tester
          .getTopLeft(find.byKey(const ValueKey('history_a')))
          .dy;
      expect(bTop, lessThan(aTop));
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('Before version 2.0'), findsOneWidget);
      expect(find.text('PASSED'), findsNWidgets(2));
      expect(find.text('NOT PASSED'), findsOneWidget);
      expect(find.byKey(const Key('exam_history_chart')), findsOneWidget);
    });

    testWidgets('an empty history says so', (tester) async {
      await h.pump(tester, home: ExamHistoryScreen(args: h.args));
      expect(find.byKey(const Key('exam_history_empty')), findsOneWidget);
    });

    testWidgets('the date is shown in local time', (tester) async {
      await h.seedAttempt(id: 'a', startedAt: DateTime(2026, 3, 1, 8, 5));
      await h.pump(tester, home: ExamHistoryScreen(args: h.args));
      expect(find.textContaining('Mar 1, 2026'), findsOneWidget);
    });
  });

  group('review', () {
    testWidgets('shows the chosen and the correct answer from the canonical '
        'indices and a line for a question that left the bank', (tester) async {
      await seedReviewable();
      await h.pump(
        tester,
        premium: true,
        home: ExamHistoryScreen(args: h.args),
      );
      await tester.tap(find.byKey(const ValueKey('history_review')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('exam_review')));
      await settle(tester);

      expect(find.text('bad1 1'), findsOneWidget);
      expect(find.text('ok 1'), findsOneWidget);
      expect(find.text('Question 1 of 3: Wrong'), findsOneWidget);
      expect(find.text('Question 2 of 3: Correct'), findsOneWidget);
      expect(
        find.text('This question is no longer in the question bank.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('review_filter_wrong')));
      await settle(tester);
      expect(find.text('Question 2 of 3: Correct'), findsNothing);
      expect(find.text('Question 1 of 3: Wrong'), findsOneWidget);
    });

    testWidgets('a free user sees the score and a teaser, not the review', (
      tester,
    ) async {
      await seedReviewable();
      await h.pump(tester, home: ExamHistoryScreen(args: h.args));
      await tester.tap(find.byKey(const ValueKey('history_review')));
      await settle(tester);

      expect(find.byKey(const Key('exam_result_score')), findsOneWidget);
      expect(find.byKey(const Key('exam_review')), findsNothing);
      expect(find.byKey(const Key('exam_train')), findsNothing);
      expect(find.byKey(const Key('exam_result_teaser')), findsOneWidget);
      await tester.tap(find.byKey(const Key('exam_teaser_premium')));
      await tester.pump();
      expect(h.paywalls, [PaywallTrigger.examResults]);
    });
  });

  group('subject screen tile', () {
    SubjectInfo subject() => SubjectInfo(
      licence: Licence.ppla,
      id: SubjectId.communications,
      title: 'Comms',
      description: '',
      spec: h.args.spec,
      questions: h.questions,
    );

    testWidgets('shows the last result and opens the history', (tester) async {
      await h.seedAttempt(correct: 10);
      await h.pump(
        tester,
        home: Scaffold(
          body: SingleChildScrollView(child: QuizList(subject: subject())),
        ),
      );

      expect(find.text('Last result: 83%, passed'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('mode_history')));
      await tester.tap(find.byKey(const Key('mode_history')));
      await settle(tester);
      expect(find.text('Exam history'), findsOneWidget);
    });

    testWidgets('opening it stores an unfinished attempt whose time is '
        'over', (tester) async {
      await h.pump(tester);
      await h.open(tester);
      await h.start(tester);
      await tester.tap(find.byKey(const Key('answer_0')));
      await settle(tester);
      await tester.pageBack();
      await settle(tester);
      await tester.tap(find.byKey(const Key('exam_leave_confirm')));
      await settle(tester);
      h.now = h.now.add(const Duration(hours: 2));

      await h.pump(
        tester,
        home: Scaffold(
          body: SingleChildScrollView(child: QuizList(subject: subject())),
        ),
      );

      final saved = await h.attempts();
      expect(saved, hasLength(1));
      expect(saved.single.reason, AttemptReason.timeout);
      expect(await h.unfinished(), isNull);
      expect(find.textContaining('Last result:'), findsOneWidget);
    });
  });

  testWidgets('a sweep updates the tile of an open subject screen', (
    tester,
  ) async {
    await h.pump(tester);
    await h.open(tester);
    await h.start(tester);
    await tester.tap(find.byKey(const Key('answer_0')));
    await settle(tester);
    await tester.pageBack();
    await settle(tester);
    await tester.tap(find.byKey(const Key('exam_leave_confirm')));
    await settle(tester);

    SubjectInfo subject() => SubjectInfo(
      licence: Licence.ppla,
      id: SubjectId.communications,
      title: 'Comms',
      description: '',
      spec: h.args.spec,
      questions: h.questions,
    );
    await h.pump(
      tester,
      home: Scaffold(
        body: SingleChildScrollView(child: QuizList(subject: subject())),
      ),
    );
    expect(find.textContaining('Unfinished attempt'), findsOneWidget);

    h.now = h.now.add(const Duration(hours: 2));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(QuizList)),
    );
    container.invalidate(examSweepProvider);
    container.read(examSweepProvider.future).ignore();
    await settle(tester);

    expect(find.textContaining('Unfinished attempt'), findsNothing);
    expect(find.textContaining('Last result:'), findsOneWidget);
  });
}
