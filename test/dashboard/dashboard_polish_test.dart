import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/progress/progress_repository.dart';

import '../bank/memory_hive.dart';
import 'dashboard_helpers.dart';

Finder _goal(String text) => find.descendant(
  of: find.byKey(const Key('dashboard_goal')),
  matching: find.text(text),
);

/// Records one recovery event the way the real opener does.
Future<void> _recordRecovery() async {
  var first = true;
  await ProgressRepository.openWithBackupUsing('recovered_box', (
    name, {
    required crashRecovery,
  }) {
    if (first) {
      first = false;
      throw HiveError('Wrong checksum');
    }
    return openMemoryBox(name);
  });
}

void main() {
  AppHarness.registerSetUp();
  setUp(ProgressRepository.clearRecoveryEvents);
  tearDown(ProgressRepository.clearRecoveryEvents);

  testWidgets('B1: the goal ring counts learning and exam answers', (
    tester,
  ) async {
    final h = AppHarness();
    await h.seedConfig();
    for (var i = 0; i < 3; i++) {
      await h.repository.recordAnswer(Licence.ppla, 'q$i', true, testNow);
    }
    for (var i = 0; i < 4; i++) {
      await h.repository.recordAnswer(
        Licence.ppla,
        'e$i',
        true,
        testNow,
        countsTowardDailyLimit: false,
      );
    }
    await h.pump(tester);

    expect(_goal('7/20'), findsOneWidget);
    // the free learning limit still looks at learning answers only
    expect((await h.repository.dailyStat(testNow)).answered, 3);
  });

  for (final (lang, title, scale) in [
    ('en', 'Saved data was damaged', 1.0),
    ('pl', 'Zapisane dane były uszkodzone', 2.0),
  ]) {
    testWidgets('A5: recovered data is announced once ($lang, x$scale)', (
      tester,
    ) async {
      tester.platformDispatcher.localesTestValue = [Locale(lang)];
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await _recordRecovery();
      expect(ProgressRepository.recoveryEvents, hasLength(1));

      final h = AppHarness();
      await h.seedConfig();
      await h.pump(tester);

      expect(find.byKey(const Key('recovery_notice')), findsOneWidget);
      expect(find.text(title), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(ProgressRepository.recoveryEvents, isEmpty);

      await tester.tap(find.byKey(const Key('recovery_notice_ok')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('recovery_notice')), findsNothing);
    });
  }

  testWidgets('A5: nothing is shown without recovery events', (tester) async {
    final h = AppHarness();
    await h.seedConfig();
    await h.pump(tester);
    expect(find.byKey(const Key('recovery_notice')), findsNothing);
  });
}
