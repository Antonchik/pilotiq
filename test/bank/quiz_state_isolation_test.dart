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
import 'package:pilotiq/src/purchases/fake_purchase_service.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';
import 'package:pilotiq/src/quiz/widgets/answer_card.dart';

import 'fake_bank.dart';
import 'memory_hive.dart';

// This test lives in its own file on purpose: ProgressRepository serialises
// writes through a process-wide queue, which cannot be shared between the
// fake-async zones of different tests of one file.
void main() {
  late ProgressRepository repository;

  setUp(() async {
    final config = await openMemoryBox('config');
    await config.put('onboardingDone', true);
    repository = memoryProgressRepository();
    PackageInfo.setMockInitialValues(
      appName: 'Pilotiq',
      packageName: 'antonchik.anton.pilotiq',
      version: '2.0.0',
      buildNumber: '15',
      buildSignature: '',
    );
  });

  tearDown(() => Hive.close());

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

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            purchaseServiceProvider.overrideWithValue(FakePurchaseService()),
            progressRepositoryProvider.overrideWithValue(repository),
            questionBankRepositoryProvider.overrideWithValue(
              fakeBankRepository(),
            ),
            randomProvider.overrideWithValue(Random(1)),
          ],
          child: const MyApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tab_subjects')));
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
