import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pilotiq/src/app.dart';
import 'package:pilotiq/src/bank/licence_provider.dart';
import 'package:pilotiq/src/bank/question_bank_repository.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/exams/licence_item.dart';
import 'package:pilotiq/src/home/home.dart';
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

  testWidgets('home screen shows the four licences', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildApp());
    await tester.pump();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(LicenceItem), findsNWidgets(4));
    for (final title in ['PPL(A)', 'PPL(H)', 'SPL', 'BPL']) {
      expect(find.text(title), findsOneWidget);
    }
  });

  testWidgets('tapping a licence card opens its subjects and remembers it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildApp());
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    expect(container.read(selectedLicenceProvider), Licence.ppla);

    await tester.tap(find.text('PPL(H)'));
    await tester.pumpAndSettle();

    expect(find.byType(SubjectListScreen), findsOneWidget);
    expect(
      tester.widget<SubjectListScreen>(find.byType(SubjectListScreen)).licence,
      Licence.pplh,
    );
    expect(find.byKey(const Key('subject_air_law')), findsOneWidget);

    // The choice is stored in the settings.
    await tester.pump();
    expect(container.read(selectedLicenceProvider), Licence.pplh);
  });
}
