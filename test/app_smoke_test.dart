import 'dart:io';

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
import 'package:pilotiq/src/purchases/fake_purchase_service.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';
import 'package:pilotiq/src/subjects/subject_list_screen.dart';

import 'bank/fake_bank.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('smoke_test_');
    Hive.init(tmp.path);
    await Hive.openBox<dynamic>('config');
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
    await tmp.delete(recursive: true);
  });

  Widget buildApp() => ProviderScope(
    overrides: [
      purchaseServiceProvider.overrideWithValue(FakePurchaseService()),
      questionBankRepositoryProvider.overrideWithValue(fakeBankRepository()),
    ],
    child: const MyApp(),
  );

  /// Pumps frames, letting real file IO of Hive finish in between, until
  /// [condition] holds. It waits for the condition, not for a fixed time.
  Future<void> pumpUntil(WidgetTester tester, bool Function() condition) async {
    for (var i = 0; i < 500 && !condition(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(condition(), isTrue, reason: 'condition was not reached in time');
  }

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
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    debugPrint('DBG ${find.byType(SubjectListScreen).evaluate().length} ${find.byType(CircularProgressIndicator).evaluate().length}');

    expect(find.byType(SubjectListScreen), findsOneWidget);
    expect(
      tester.widget<SubjectListScreen>(find.byType(SubjectListScreen)).licence,
      Licence.pplh,
    );
    expect(find.byKey(const Key('subject_air_law')), findsOneWidget);

    // The choice is stored (asynchronously) in the settings.
    await pumpUntil(
      tester,
      () => container.read(selectedLicenceProvider) == Licence.pplh,
    );
  });
}
