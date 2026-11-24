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

import '../bank/fake_bank.dart';
import '../bank/memory_hive.dart';
import 'exam_helpers.dart';

/// Two exams in a row through the real app: the second never inherits the
/// state of the first, and both attempts are stored.
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

  testWidgets('a new exam never inherits the state of the previous one', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          purchaseServiceProvider.overrideWithValue(
            FakePurchaseService(premium: true),
          ),
          progressRepositoryProvider.overrideWithValue(repository),
          questionBankRepositoryProvider.overrideWithValue(
            fakeBankRepository(),
          ),
          randomProvider.overrideWithValue(Random(1)),
        ],
        child: const MyApp(),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const Key('tab_subjects')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('subject_air_law')));
    await settle(tester);

    Future<void> playExam() async {
      final exam = find.byKey(const Key('mode_exam'));
      await tester.ensureVisible(exam);
      await tester.tap(exam, warnIfMissed: false);
      await settle(tester);
      expect(find.text('4 questions'), findsOneWidget);
      await tester.tap(find.byKey(const Key('exam_start')));
      await settle(tester);
      expect(find.text('Question 1 of 4'), findsOneWidget);
      expect(find.text('0 answered'), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const Key('answer_0')));
        await tester.pump();
        if (i < 3) {
          await tester.tap(find.byKey(const Key('exam_next')));
          await settle(tester);
        }
      }
      await tester.tap(find.byKey(const Key('exam_finish_inline')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('exam_finish_confirm')));
      await settle(tester);
      expect(find.byKey(const Key('exam_result_percent')), findsOneWidget);
    }

    await playExam();
    await tester.tap(find.byKey(const Key('exam_result_back')));
    // Open the next exam while the previous screen is still animating out.
    await tester.pump(const Duration(milliseconds: 60));
    await playExam();
    await tester.tap(find.byKey(const Key('exam_result_back')));
    await settle(tester);

    final attempts = await repository.attempts(
      Licence.ppla,
      subject: SubjectId.airLaw,
    );
    expect(attempts, hasLength(2));
    expect(attempts.map((a) => a.id).toSet(), hasLength(2));
  });
}
