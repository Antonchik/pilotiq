import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pilotiq/src/progress/progress_repository.dart';
import 'package:pilotiq/src/purchases/paywall_launcher.dart';

import '../bank/memory_hive.dart';
import 'dashboard_helpers.dart';

/// A repository whose first [failures] settings saves throw.
class _FlakyRepository extends ProgressRepository {
  _FlakyRepository(this.failures) : super(openBox: openMemoryBox);

  int failures;

  @override
  Future<void> saveSettings(settings, {bool themeChosen = false}) async {
    if (failures > 0) {
      failures--;
      throw StateError('box could not be opened');
    }
    return super.saveSettings(settings, themeChosen: themeChosen);
  }
}

Future<void> _openProfile(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('tab_profile')));
  await tester.pumpAndSettle();
}

void main() {
  AppHarness.registerSetUp();

  testWidgets('daily goal, exam date and theme are saved to the config', (
    tester,
  ) async {
    final h = AppHarness();
    await h.seedConfig();
    await h.pump(tester);
    await _openProfile(tester);
    final config = Hive.box<dynamic>('config');

    await tester.tap(find.byKey(const Key('settings_daily_goal')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('goal_option_40')));
    await tester.pumpAndSettle();
    expect(config.get('dailyGoal'), 40);
    expect(find.text('40 questions per day'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings_exam_date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(config.get('examDate'), '2026-12-23'); // 30 days after the clock

    await tester.tap(find.byKey(const Key('settings_exam_date_clear')));
    await tester.pumpAndSettle();
    expect(config.get('examDate'), isNull);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(config.get('themeMode'), 'dark');
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('choosing a licence stores it and the subjects tab follows', (
    tester,
  ) async {
    final h = AppHarness();
    await h.seedConfig();
    await h.pump(tester);
    await _openProfile(tester);

    await tester.tap(find.byKey(const Key('settings_licence')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('licence_option_pplh')));
    await tester.pumpAndSettle();

    expect(Hive.box<dynamic>('config').get('licence'), 'pplh');
    await tester.tap(find.byKey(const Key('tab_subjects')));
    await tester.pumpAndSettle();
    expect(find.textContaining('PPL(H)'), findsWidgets);
  });

  testWidgets('a failed save keeps the old value and offers a retry', (
    tester,
  ) async {
    final repository = _FlakyRepository(1);
    final h = AppHarness(repository: repository);
    await h.seedConfig();
    await h.pump(tester);
    await _openProfile(tester);

    await tester.tap(find.byKey(const Key('settings_daily_goal')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('goal_option_10')));
    await tester.pumpAndSettle();

    expect(find.text('Could not save the setting.'), findsOneWidget);
    expect(find.text('20 questions per day'), findsOneWidget);
    expect(Hive.box<dynamic>('config').get('dailyGoal'), isNull);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(Hive.box<dynamic>('config').get('dailyGoal'), 10);
    expect(find.text('10 questions per day'), findsOneWidget);
  });

  testWidgets('free users open the paywall from the profile', (tester) async {
    final h = AppHarness();
    await h.seedConfig();
    await h.pump(tester);
    await _openProfile(tester);

    await tester.tap(find.byKey(const Key('settings_premium')));
    await tester.pump();
    expect(h.paywalls, [PaywallTrigger.profile]);
  });

  testWidgets('premium users see their status instead of the paywall', (
    tester,
  ) async {
    final h = AppHarness(premium: true);
    await h.seedConfig();
    await h.pump(tester);
    await _openProfile(tester);

    expect(find.text('Premium is active'), findsOneWidget);
    await tester.tap(find.byKey(const Key('settings_premium')));
    await tester.pump();
    expect(h.paywalls, isEmpty);
  });

  testWidgets('About shows version, disclaimer and the source of each bank', (
    tester,
  ) async {
    final h = AppHarness();
    await h.seedConfig();
    await h.pump(tester);
    await _openProfile(tester);

    await tester.ensureVisible(find.byKey(const Key('settings_about')));
    await tester.tap(find.byKey(const Key('settings_about')));
    await tester.pumpAndSettle();

    expect(find.text('Version 2.0.0 (15)'), findsOneWidget);
    expect(
      find.text(
        'Pilotiq is not affiliated with ULC or EASA and is not their product.',
      ),
      findsOneWidget,
    );
    for (final licence in ['PPL(A)', 'PPL(H)', 'SPL', 'BPL']) {
      expect(
        find.text(
          '$licence: ULC, Przykładowe pytania egzaminacyjne, 01.08.2024',
        ),
        findsOneWidget,
      );
    }
    expect(
      find.text('Question texts are given as published by ULC.'),
      findsOneWidget,
    );
  });

  testWidgets('the info button of an app bar opens About', (tester) async {
    final h = AppHarness();
    await h.seedConfig();
    await h.pump(tester);
    await tester.tap(find.byKey(const Key('tab_subjects')));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('about_disclaimer')), findsOneWidget);
  });
}
