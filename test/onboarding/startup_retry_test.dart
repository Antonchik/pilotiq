import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilotiq/src/app.dart';
import 'package:pilotiq/src/progress/providers.dart';

import '../bank/memory_hive.dart';

void main() {
  testWidgets('a retry shows the loading indicator and cannot run twice', (
    tester,
  ) async {
    final attempts = <Completer<ProviderContainer>>[];
    await tester.pumpWidget(
      PilotiqRoot(
        initialize: () {
          final c = Completer<ProviderContainer>();
          attempts.add(c);
          return c.future;
        },
      ),
    );
    attempts.single.completeError(StateError('first'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('startup_retry')), findsOneWidget);

    await tester.tap(find.byKey(const Key('startup_retry')));
    await tester.pump();

    // While the second start runs: loading, no error screen, no button.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('startup_retry')), findsNothing);
    expect(attempts, hasLength(2));
  });

  testWidgets('the container of a replaced or disposed start is released', (
    tester,
  ) async {
    final late = ProviderContainer();
    final done = Completer<ProviderContainer>();
    await tester.pumpWidget(PilotiqRoot(initialize: () => done.future));
    await tester.pump();

    // The widget goes away while the start is still running.
    await tester.pumpWidget(const SizedBox());
    done.complete(late);
    await tester.pumpAndSettle();

    expect(() => late.read(clockProvider), throwsStateError);
  });

  testWidgets('a successful retry shows the app', (tester) async {
    var calls = 0;
    final container = ProviderContainer(
      overrides: [
        progressRepositoryProvider.overrideWithValue(
          memoryProgressRepository(),
        ),
      ],
    );
    await tester.pumpWidget(
      PilotiqRoot(
        initialize: () async {
          calls++;
          if (calls == 1) throw StateError('first');
          return container;
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('startup_retry')));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.byKey(const Key('startup_retry')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
