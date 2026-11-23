import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pilotiq/src/app.dart';
import 'package:pilotiq/src/bank/question_bank_repository.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/progress/progress_repository.dart';
import 'package:pilotiq/src/progress/providers.dart';
import 'package:pilotiq/src/quiz/widgets/answer_card.dart';
import 'package:pilotiq/src/purchases/fake_purchase_service.dart';
import 'package:pilotiq/src/purchases/paywall_launcher.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';

import 'fake_bank.dart';
import 'memory_hive.dart';

void main() {
  late List<PaywallTrigger> paywalls;
  late ProgressRepository repository;

  setUp(() async {
    await openMemoryBox('config');
    paywalls = [];
    repository = memoryProgressRepository();
    PackageInfo.setMockInitialValues(
      appName: 'Pilotiq',
      packageName: 'antonchik.anton.pilotiq',
      version: '2.0.0',
      buildNumber: '15',
      buildSignature: '',
    );
  });

  tearDown(() async {
    await Hive.close();
  });

  Future<void> start(WidgetTester tester, {String? language}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Let fire-and-forget progress writes finish: the repository serialises
    // writes in a process-wide queue, so a write left pending would block the
    // next test.
    addTearDown(() => tester.pumpAndSettle());
    if (language != null) {
      await Hive.box<dynamic>('config').put('questionLanguage', language);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          purchaseServiceProvider.overrideWithValue(FakePurchaseService()),
          progressRepositoryProvider.overrideWithValue(repository),
          questionBankRepositoryProvider.overrideWithValue(
            fakeBankRepository(),
          ),
          paywallOpenerProvider.overrideWithValue((context, trigger) async {
            paywalls.add(trigger);
          }),
          // Deterministic answer order: keeps every answer at its position.
          randomProvider.overrideWithValue(_NoShuffleRandom()),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openLearnMode(WidgetTester tester, String licenceTitle) async {
    await tester.tap(find.text(licenceTitle));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('subject_air_law')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mode_learn')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.start));
    await tester.pumpAndSettle();
  }

  testWidgets('PPL(H) with English shows the English question and answers', (
    tester,
  ) async {
    await start(tester, language: 'en');
    await openLearnMode(tester, 'PPL(H)');

    expect(find.text('Height above ground is'), findsOneWidget);
    expect(find.text('Wysokość nad ziemią to'), findsNothing);
    expect(find.text('AGL'), findsOneWidget);
  });

  testWidgets('PPL(H) with Polish shows the Polish question', (tester) async {
    await start(tester);
    await openLearnMode(tester, 'PPL(H)');

    expect(find.text('Wysokość nad ziemią to'), findsOneWidget);
    expect(find.text('Height above ground is'), findsNothing);
  });

  testWidgets('SPL ignores the English setting (no English bank)', (
    tester,
  ) async {
    await start(tester, language: 'en');
    await openLearnMode(tester, 'SPL');

    expect(find.text('Wysokość nad ziemią to'), findsOneWidget);
  });

  testWidgets(
    'English with a missing answer translation shows the whole question in '
    'Polish',
    (tester) async {
      await start(tester, language: 'en');
      await openLearnMode(tester, 'PPL(H)');
      // Answer the first question correctly (position 0) to reach the second.
      await tester.tap(find.text('AGL'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('Pytanie z brakiem'), findsOneWidget);
      expect(find.text('Missing question'), findsNothing);
      for (final pl in [
        'Odpowiedź pierwsza',
        'Odpowiedź druga',
        'Odpowiedź trzecia',
        'Odpowiedź czwarta',
      ]) {
        expect(find.text(pl), findsOneWidget);
      }
      expect(find.text('First answer'), findsNothing);
      expect(find.text('Second answer'), findsNothing);
    },
  );

  testWidgets('sub, sup and the "/n" tail are not shown as source tags', (
    tester,
  ) async {
    await start(tester, language: 'en');
    await openLearnMode(tester, 'PPL(H)');
    // Answer questions 1..3 correctly (the correct one is shown first, the
    // second question is shown in Polish) to reach question 4 with markup.
    for (final answer in ['AGL', 'Odpowiedź pierwsza', 'A']) {
      await tester.tap(find.text(answer));
      await tester.pumpAndSettle(const Duration(seconds: 1));
    }

    expect(
      find.textContaining('Formula H', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('<sub>', findRichText: true), findsNothing);
    expect(find.textContaining('<sup>', findRichText: true), findsNothing);
    expect(find.textContaining('/n', findRichText: true), findsNothing);
    expect(find.text('one'), findsOneWidget);
  });

  testWidgets('"Go Premium" on the subject screen opens the locked-feature '
      'paywall', (tester) async {
    await start(tester);
    await tester.tap(find.text('PPL(A)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('subject_air_law')));
    await tester.pumpAndSettle();

    final button = find.widgetWithText(ElevatedButton, 'Go Premium!');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pump();

    expect(paywalls, [PaywallTrigger.lockedFeature]);
  });

  testWidgets(
    'a new exam screen never inherits the state of the previous one',
    (tester) async {
      // The legacy countdown timer (removed by the exam step) overflows its
      // fixed 65 px box with the wide test font; that is unrelated here.
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        previous?.call(details);
      };
      addTearDown(() => FlutterError.onError = previous);

      await start(tester);
      await tester.tap(find.text('PPL(A)'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('subject_air_law')));
      await tester.pumpAndSettle();

      Future<void> playExam() async {
        final exam = find.byKey(const Key('mode_exam'));
        await tester.ensureVisible(exam);
        await tester.tap(exam, warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.text('0/4'), findsOneWidget, reason: 'fresh start page');
        await tester.tap(find.byIcon(Icons.start));
        await tester.pumpAndSettle();
        for (var i = 0; i < 4; i++) {
          await tester.tap(find.byType(AnswerCard).first);
          await tester.pumpAndSettle();
        }
        expect(find.text('Return to subject'), findsOneWidget);
      }

      await playExam();
      await tester.tap(find.text('Return to subject'));
      // Open the next exam while the previous screen is still animating out.
      await tester.pump(const Duration(milliseconds: 60));
      await playExam();
      await tester.tap(find.text('Return to subject'));
      await tester.pumpAndSettle();

      final attempts = await repository.attempts(
        Licence.ppla,
        subject: SubjectId.airLaw,
      );
      expect(attempts, hasLength(2));
    },
  );
}

/// A [Random] that makes `List.shuffle` keep the order of the list.
class _NoShuffleRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => max - 1;
}
