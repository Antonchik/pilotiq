import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pilotiq/src/app.dart';
import 'package:pilotiq/src/bank/licence_provider.dart';
import 'package:pilotiq/src/bank/question_bank_repository.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/home/home.dart';
import 'package:pilotiq/src/onboarding/onboarding_screen.dart';
import 'package:pilotiq/src/progress/providers.dart';
import 'package:pilotiq/src/purchases/fake_purchase_service.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';
import 'package:pilotiq/src/subjects/subject_list_screen.dart';

import 'bank/fake_bank.dart';
import 'bank/memory_hive.dart';

void main() {
  setUp(() async {
    await openMemoryBox('config');
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

  Widget buildApp() => ProviderScope(
    overrides: [
      purchaseServiceProvider.overrideWithValue(FakePurchaseService()),
      progressRepositoryProvider.overrideWithValue(memoryProgressRepository()),
      questionBankRepositoryProvider.overrideWithValue(fakeBankRepository()),
    ],
    child: const MyApp(),
  );

  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('the first launch opens the onboarding', (tester) async {
    bigScreen(tester);
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('after the onboarding the home screen has three tabs', (
    tester,
  ) async {
    bigScreen(tester);
    await Hive.box<dynamic>('config').put('onboardingDone', true);
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    for (final tab in ['tab_today', 'tab_subjects', 'tab_profile']) {
      expect(find.byKey(Key(tab)), findsOneWidget);
    }
  });

  for (final licence in Licence.values) {
    testWidgets('${licence.id}: its subjects open from the Subjects tab', (
      tester,
    ) async {
      bigScreen(tester);
      final config = Hive.box<dynamic>('config');
      await config.put('onboardingDone', true);
      await config.put('licence', licence.id);
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      expect(container.read(selectedLicenceProvider), licence);

      await tester.tap(find.byKey(const Key('tab_subjects')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<SubjectListScreen>(find.byType(SubjectListScreen))
            .licence,
        licence,
      );
      expect(find.byKey(const Key('subject_air_law')), findsOneWidget);
    });
  }
}
