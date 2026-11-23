import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilotiq/src/app.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/progress/progress_repository.dart';
import 'package:pilotiq/src/progress/providers.dart';

import '../bank/memory_hive.dart';
import 'dashboard_helpers.dart';

Finder _goal(String text) => find.descendant(
  of: find.byKey(const Key('dashboard_goal')),
  matching: find.text(text),
);

void main() {
  AppHarness.registerSetUp();

  testWidgets('the dashboard recomputes when the local day changes', (
    tester,
  ) async {
    var t = DateTime(2026, 11, 23, 23, 59, 58);
    final h = AppHarness(clock: Clock(() => t));
    await h.seedConfig();
    for (var i = 0; i < 3; i++) {
      await h.repository.recordAnswer(Licence.ppla, 'PL010-0001', true, t);
    }
    await h.pump(tester);
    expect(_goal('3/20'), findsOneWidget);

    t = DateTime(2026, 11, 24, 0, 0, 1);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(_goal('0/20'), findsOneWidget);
  });

  testWidgets('returning from the background refreshes the dashboard', (
    tester,
  ) async {
    final h = AppHarness();
    await h.seedConfig();
    await h.pump(tester);
    expect(_goal('0/20'), findsOneWidget);

    await h.repository.recordAnswer(Licence.ppla, 'PL010-0001', true, testNow);
    final binding = tester.binding;
    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      binding.handleAppLifecycleStateChanged(s);
    }
    await tester.pumpAndSettle();

    expect(_goal('1/20'), findsOneWidget);
  });

  testWidgets(
    'a progress box that fails to open: message about the data and a retry '
    'that really recovers',
    (tester) async {
      var created = 0;
      final h = AppHarness(
        repositoryOverride: progressRepositoryProvider.overrideWith((ref) {
          final first = ++created == 1;
          return ProgressRepository(
            openBox: (name) {
              if (first && name.startsWith('progress_')) {
                throw StateError('cannot open $name');
              }
              return openMemoryBox(name);
            },
          );
        }),
      );
      await h.seedConfig();
      await h.pump(tester);

      expect(find.text('Could not open your progress data.'), findsOneWidget);
      expect(find.text('Could not load the question bank.'), findsNothing);

      await tester.tap(find.byKey(const Key('dashboard_retry')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dashboard_goal')), findsOneWidget);
      expect(created, 2);
    },
  );

  testWidgets('PilotiqRoot disposes its container', (tester) async {
    final container = ProviderContainer();
    await tester.pumpWidget(PilotiqRoot(initialize: () async => container));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();

    expect(() => container.read(clockProvider), throwsStateError);
  });
}
