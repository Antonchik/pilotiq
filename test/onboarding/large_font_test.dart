import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pilotiq/src/app.dart';
import 'package:pilotiq/src/home/home.dart';
import 'package:pilotiq/src/onboarding/onboarding_screen.dart';

import '../dashboard/dashboard_helpers.dart';

/// Large system fonts and narrow screens: every action of the onboarding,
/// the settings, the About screen, the start-up error and the dialogs must
/// stay reachable and must not overflow (an overflow fails the test).
void main() {
  AppHarness.registerSetUp();

  final combos = [
    for (final lang in ['en', 'pl'])
      for (final scale in [1.3, 1.5, 2.0])
        for (final width in [320.0, 360.0]) (lang, scale, width),
  ];

  void configure(WidgetTester tester, String lang, double scale, double w) {
    tester.view.physicalSize = Size(w, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    tester.platformDispatcher.localesTestValue = [Locale(lang)];
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearAllTestValues();
    });
  }

  /// Scrolls the first list of the screen until [finder] is built.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isNotEmpty) return;
    final list = find.byType(Scrollable).first;
    if (list.evaluate().isEmpty) return;
    for (final delta in [300.0, -300.0]) {
      for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
        await tester.drag(list, Offset(0, delta));
        await tester.pump();
      }
      if (finder.evaluate().isNotEmpty) return;
    }
  }

  /// Taps [finder] after checking that it lies inside the screen.
  Future<void> reach(
    WidgetTester tester,
    Finder finder, {
    bool tap = true,
  }) async {
    await scrollTo(tester, finder);
    expect(finder, findsOneWidget);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    final rect = tester.getRect(finder);
    final screen = tester.view.physicalSize;
    expect(rect.left, greaterThanOrEqualTo(0), reason: '$finder');
    expect(rect.right, lessThanOrEqualTo(screen.width), reason: '$finder');
    expect(rect.bottom, lessThanOrEqualTo(screen.height), reason: '$finder');
    if (!tap) return;
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> pumpApp(WidgetTester tester, AppHarness h) async {
    await tester.pumpWidget(
      ProviderScope(overrides: h.overrides, child: const MyApp()),
    );
    await tester.pumpAndSettle();
  }

  for (final (lang, scale, width) in combos) {
    final name = '$lang x$scale ${width.toInt()}dp';

    testWidgets('onboarding can be completed: $name', (tester) async {
      configure(tester, lang, scale, width);
      final h = AppHarness();
      await pumpApp(tester, h);

      await reach(tester, find.byKey(const Key('onboarding_licence_pplh')));
      await reach(tester, find.byKey(const Key('onboarding_next')));
      await reach(tester, find.byKey(const Key('onboarding_exam_date')));
      await reach(tester, find.text('OK'));
      await reach(tester, find.byKey(const Key('onboarding_back')));
      await reach(tester, find.byKey(const Key('onboarding_next')));
      await reach(tester, find.byKey(const Key('onboarding_skip')));
      await reach(tester, find.byKey(const Key('onboarding_goal_40')));
      await reach(tester, find.byKey(const Key('onboarding_finish')));

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(Hive.box<dynamic>('config').get('onboardingDone'), true);
    });

    testWidgets('settings, dialogs and About are usable: $name', (
      tester,
    ) async {
      configure(tester, lang, scale, width);
      final h = AppHarness();
      await h.seedConfig({'examDate': '2026-12-03'});
      await pumpApp(tester, h);

      await reach(tester, find.byKey(const Key('tab_profile')));
      await reach(tester, find.byKey(const Key('settings_premium')));
      // Dialogs: pick, which closes them.
      await reach(tester, find.byKey(const Key('settings_licence')));
      await reach(tester, find.byKey(const Key('licence_option_bpl')));
      await reach(tester, find.byKey(const Key('settings_daily_goal')));
      await reach(tester, find.byKey(const Key('goal_option_40')));
      await reach(tester, find.byKey(const Key('settings_exam_date')));
      await reach(tester, find.text('OK'));
      await reach(tester, find.byKey(const Key('settings_exam_date_clear')));
      await reach(tester, find.byKey(const Key('settings_about')));

      expect(find.byKey(const Key('about_disclaimer')), findsOneWidget);
      await scrollTo(tester, find.byKey(const Key('about_source_bpl')));
      expect(find.byKey(const Key('about_source_bpl')), findsOneWidget);
      expect(Hive.box<dynamic>('config').get('dailyGoal'), 40);
    });

    testWidgets('dashboard has no overflow: $name', (tester) async {
      configure(tester, lang, scale, width);
      final h = AppHarness(premium: true);
      await h.seedConfig({'examDate': '2026-12-03'});
      await pumpApp(tester, h);

      expect(find.byKey(const Key('dashboard_goal')), findsOneWidget);
      await scrollTo(tester, find.byKey(const Key('dashboard_last_exam')));
      expect(find.byKey(const Key('dashboard_last_exam')), findsOneWidget);
    });

    testWidgets('start-up error screen: $name', (tester) async {
      configure(tester, lang, scale, width);
      await tester.pumpWidget(
        PilotiqRoot(initialize: () async => throw StateError('x')),
      );
      await tester.pumpAndSettle();
      await reach(tester, find.byKey(const Key('startup_retry')), tap: false);
    });
  }
}
