import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/home/home.dart';
import 'package:pilotiq/src/onboarding/onboarding_screen.dart';
import 'package:pilotiq/src/progress/exam_attempt.dart';

import '../dashboard/dashboard_helpers.dart';

void main() {
  AppHarness.registerSetUp();

  testWidgets('the first launch shows the onboarding and saves the choices', (
    tester,
  ) async {
    final h = AppHarness();
    await h.pump(tester);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(find.byKey(const Key('onboarding_legacy_banner')), findsNothing);

    await tester.tap(find.byKey(const Key('onboarding_licence_pplh')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();

    expect(find.text('When is your exam?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding_exam_date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('onboarding_goal_40')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding_finish')));
    await tester.pumpAndSettle();

    final config = Hive.box<dynamic>('config');
    expect(config.get('licence'), 'pplh');
    expect(config.get('questionLanguage'), 'en');
    expect(config.get('examDate'), '2026-12-23');
    expect(config.get('dailyGoal'), 40);
    expect(config.get('onboardingDone'), true);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('the exam date can be skipped', (tester) async {
    final h = AppHarness();
    await h.pump(tester);
    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding_skip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding_finish')));
    await tester.pumpAndSettle();

    final config = Hive.box<dynamic>('config');
    expect(config.get('onboardingDone'), true);
    expect(config.get('examDate'), isNull);
    expect(config.get('dailyGoal'), 20);
    expect(config.get('licence'), 'ppla');
  });

  testWidgets('back keeps the choices of earlier steps', (tester) async {
    final h = AppHarness();
    await h.pump(tester);
    await tester.tap(find.byKey(const Key('onboarding_licence_spl')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding_back')));
    await tester.pumpAndSettle();

    final card = tester.widget<Card>(
      find.byKey(const Key('onboarding_licence_spl')),
    );
    expect((card.shape! as RoundedRectangleBorder).side.width, 2);
    // SPL has no English bank: the hint replaces the language switch.
    expect(find.byKey(const Key('onboarding_language')), findsNothing);
  });

  testWidgets('upgrading users get the licence of their results pre-selected', (
    tester,
  ) async {
    final h = AppHarness();
    await h.repository.saveAttempt(
      ExamAttempt(
        id: 'legacy_pplh_meteorology_fail_0',
        licence: Licence.pplh,
        subject: SubjectId.meteorology,
        startedAt: DateTime.utc(1970),
        finishedAt: DateTime.utc(1970),
        durationSec: 0,
        total: 0,
        correct: 0,
        passed: false,
        reason: AttemptReason.legacy,
      ),
    );
    await h.pump(tester);

    expect(find.byKey(const Key('onboarding_legacy_banner')), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding_skip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding_finish')));
    await tester.pumpAndSettle();

    expect(Hive.box<dynamic>('config').get('licence'), 'pplh');
  });
}
