import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pilotiq/src/app.dart';
import 'package:pilotiq/src/exams/exam_item.dart';
import 'package:pilotiq/src/hive_box_provider.dart';
import 'package:pilotiq/src/home/home.dart';
import 'package:pilotiq/src/purchases/fake_purchase_service.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';

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
    ],
    child: const MyApp(),
  );

  testWidgets('home screen shows six exam cards', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildApp());
    await tester.pump();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(ExamItem), findsNWidgets(6));
  });

  testWidgets('tapping PPL(H) ENG selects the pplhEng exam', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildApp());
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    expect(container.read(curExamNameProvider), ExamType.ppla.name);

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('exam_pplhEng')));
      // Let the box open (real file IO) and the navigation start.
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    expect(container.read(curExamNameProvider), ExamType.pplhEng.name);
    expect(Hive.isBoxOpen(ExamType.pplhEng.name), isTrue);
    expect(Hive.isBoxOpen(ExamType.pplh.name), isFalse);
  });
}
