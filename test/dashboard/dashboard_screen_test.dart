import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilotiq/src/dashboard/dashboard_providers.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/home/home.dart';
import 'package:pilotiq/src/progress/exam_attempt.dart';
import 'package:pilotiq/src/progress/progress_repository.dart';
import 'package:pilotiq/src/purchases/paywall_launcher.dart';
import 'package:pilotiq/src/subjects/subject_list_screen.dart';

import '../bank/fake_bank.dart';
import 'dashboard_helpers.dart';

Finder _inside(String key, Finder what) =>
    find.descendant(of: find.byKey(Key(key)), matching: what);

Future<void> _answers(
  ProgressRepository repo,
  DateTime day,
  int count, {
  bool correct = true,
}) async {
  for (var i = 0; i < count; i++) {
    await repo.recordAnswer(
      Licence.ppla,
      'PL010-000${1 + i % 4}',
      correct,
      day,
    );
  }
}

void main() {
  AppHarness.registerSetUp();

  testWidgets('shows 15/20 today, a 3-day streak and 10 days to the exam', (
    tester,
  ) async {
    final h = AppHarness();
    await h.seedConfig({'examDate': '2026-12-03', 'dailyGoal': 20});
    await _answers(h.repository, testNow, 15);
    await _answers(h.repository, testNow.subtract(const Duration(days: 1)), 2);
    await _answers(h.repository, testNow.subtract(const Duration(days: 2)), 1);
    await h.pump(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(_inside('dashboard_goal', find.text('15/20')), findsOneWidget);
    expect(
      _inside('dashboard_streak', find.textContaining('3 days in a row')),
      findsOneWidget,
    );
    expect(
      _inside('dashboard_exam', find.text('10 days to the exam')),
      findsOneWidget,
    );
    expect(find.text('5 more answers to reach the goal'), findsOneWidget);
  });

  testWidgets('exam today', (tester) async {
    final h = AppHarness();
    await h.seedConfig({'examDate': '2026-11-23'});
    await h.pump(tester);

    expect(find.text('The exam is today'), findsOneWidget);
  });

  testWidgets('a past exam date offers to set a new one', (tester) async {
    final h = AppHarness();
    await h.seedConfig({'examDate': '2026-11-20'});
    await h.pump(tester);

    expect(find.text('The exam date has passed'), findsOneWidget);
    expect(find.byKey(const Key('dashboard_exam_set')), findsOneWidget);
  });

  testWidgets('no exam date shows the hint', (tester) async {
    final h = AppHarness();
    await h.seedConfig();
    await h.pump(tester);

    expect(
      find.text('Set your exam date to see the countdown'),
      findsOneWidget,
    );
  });

  testWidgets('free: readiness is a teaser that opens the paywall', (
    tester,
  ) async {
    final h = AppHarness();
    await h.seedConfig();
    await h.pump(tester);

    expect(find.byKey(const Key('dashboard_readiness_locked')), findsOneWidget);
    expect(find.byKey(const Key('readiness_air_law')), findsNothing);
    // Basic statistics stay free.
    expect(find.byKey(const Key('dashboard_overview')), findsOneWidget);

    await tester.tap(find.byKey(const Key('dashboard_readiness')));
    await tester.pump();
    expect(h.paywalls, [PaywallTrigger.lockedFeature]);
  });

  testWidgets('premium: readiness by subject, marked as approximate', (
    tester,
  ) async {
    final h = AppHarness(premium: true);
    await h.seedConfig();
    await h.pump(tester);

    expect(find.byKey(const Key('dashboard_readiness_locked')), findsNothing);
    expect(find.byKey(const Key('readiness_air_law')), findsOneWidget);
    expect(find.byKey(const Key('readiness_meteorology')), findsOneWidget);
    expect(find.textContaining('approximate'), findsOneWidget);
  });

  testWidgets('due today counts questions due until the end of the day', (
    tester,
  ) async {
    final h = AppHarness(premium: true);
    await h.seedConfig();
    final yesterday = testNow.subtract(const Duration(days: 1));
    // Wrong answers go to box 1: due one calendar day later at the same time.
    await h.repository.recordAnswer(
      Licence.ppla,
      'PL010-0001',
      false,
      DateTime(yesterday.year, yesterday.month, yesterday.day, 10),
    ); // due today 10:00, already past
    await h.repository.recordAnswer(
      Licence.ppla,
      'PL010-0002',
      false,
      DateTime(yesterday.year, yesterday.month, yesterday.day, 20),
    ); // due today 20:00, later than "now" but still today
    await h.repository.recordAnswer(
      Licence.ppla,
      'PL010-0003',
      false,
      DateTime(testNow.year, testNow.month, testNow.day, 9),
    ); // due tomorrow
    await h.pump(tester);

    expect(
      _inside('dashboard_due', find.text('2 questions to review today')),
      findsOneWidget,
    );
  });

  testWidgets('free: the repetition card is a teaser with the paywall', (
    tester,
  ) async {
    final h = AppHarness();
    await h.seedConfig();
    await h.pump(tester);

    expect(
      _inside('dashboard_due', find.textContaining('part of Premium')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('dashboard_due')));
    await tester.pump();
    expect(h.paywalls, [PaywallTrigger.lockedFeature]);
  });

  testWidgets('premium: the repetition card leads to the subject list', (
    tester,
  ) async {
    final h = AppHarness(premium: true);
    await h.seedConfig();
    await h.pump(tester);

    await tester.tap(find.byKey(const Key('dashboard_due')));
    await tester.pumpAndSettle();
    expect(find.byType(SubjectListScreen), findsOneWidget);
  });

  testWidgets('migrated attempts: "before version 2.0", no date, no stats', (
    tester,
  ) async {
    final h = AppHarness();
    await h.seedConfig();
    for (var i = 0; i < 3; i++) {
      await h.repository.saveAttempt(
        ExamAttempt(
          id: 'legacy_$i',
          licence: Licence.ppla,
          subject: SubjectId.airLaw,
          startedAt: DateTime.utc(1970),
          finishedAt: DateTime.utc(1970),
          durationSec: 0,
          total: 0,
          correct: 0,
          passed: i > 0,
          reason: AttemptReason.legacy,
        ),
      );
    }
    await h.pump(tester);

    expect(
      _inside(
        'dashboard_last_exam',
        find.text('3 attempts before version 2.0'),
      ),
      findsOneWidget,
    );
    expect(
      _inside('dashboard_last_exam', find.text('No exam simulations yet.')),
      findsOneWidget,
    );
    expect(find.textContaining('1970'), findsNothing);
    expect(
      _inside('dashboard_streak', find.textContaining('No streak')),
      findsOneWidget,
    );
    expect(_inside('dashboard_goal', find.text('0/20')), findsOneWidget);
  });

  testWidgets('last simulation shows result, date and badge', (tester) async {
    final h = AppHarness();
    await h.seedConfig();
    await h.repository.saveAttempt(
      ExamAttempt(
        id: 'a',
        licence: Licence.ppla,
        subject: SubjectId.airLaw,
        startedAt: DateTime(2026, 11, 20, 10),
        finishedAt: DateTime(2026, 11, 20, 10, 40),
        durationSec: 2400,
        total: 12,
        correct: 9,
        passed: true,
        reason: AttemptReason.finished,
      ),
    );
    await h.pump(tester);

    expect(
      _inside('dashboard_last_exam', find.textContaining('75% · ')),
      findsOneWidget,
    );
    expect(_inside('dashboard_last_exam', find.text('Passed')), findsOneWidget);
  });

  testWidgets('a bank that fails to load shows a message with retry', (
    tester,
  ) async {
    final bundle = FakeBankBundle()..failures['assets/data/bank_ppla.json'] = 1;
    final h = AppHarness(bank: fakeBankRepository(bundle));
    await h.seedConfig();
    await h.pump(tester);

    expect(find.text('Could not load the question bank.'), findsOneWidget);
    expect(find.byKey(const Key('dashboard_goal')), findsNothing);

    await tester.tap(find.byKey(const Key('dashboard_retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dashboard_goal')), findsOneWidget);
    expect(find.text('Could not load the question bank.'), findsNothing);
  });

  testWidgets('switching tabs recomputes the dashboard', (tester) async {
    final h = AppHarness();
    await h.seedConfig();
    await h.pump(tester);
    expect(_inside('dashboard_goal', find.text('0/20')), findsOneWidget);

    await _answers(h.repository, testNow, 4);
    await tester.tap(find.byKey(const Key('tab_subjects')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab_today')));
    await tester.pumpAndSettle();

    expect(_inside('dashboard_goal', find.text('4/20')), findsOneWidget);
  });

  testWidgets('system back from another tab returns to Today', (tester) async {
    final h = AppHarness();
    await h.seedConfig();
    await h.pump(tester);
    await tester.tap(find.byKey(const Key('tab_profile')));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    expect(container.read(homeTabProvider), 0);
  });
}
