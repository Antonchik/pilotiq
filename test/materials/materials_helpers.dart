import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pilotiq/src/bank/models.dart';
import 'package:pilotiq/src/bank/question_bank_repository.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/materials/materials_providers.dart';
import 'package:pilotiq/src/materials/materials_repository.dart';
import 'package:pilotiq/src/materials/report_error.dart';
import 'package:pilotiq/src/progress/progress_repository.dart';
import 'package:pilotiq/src/progress/providers.dart';
import 'package:pilotiq/src/purchases/fake_purchase_service.dart';
import 'package:pilotiq/src/purchases/paywall_launcher.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';
import 'package:pilotiq/src/quiz/practice/practice_controller.dart';
import 'package:pilotiq/src/quiz/practice/practice_session.dart';
import 'package:pilotiq/src/subjects/subject_info.dart';

import '../bank/fake_bank.dart';
import '../bank/memory_hive.dart';

/// Content keys of `fixtures/air_law_fixture.json`.
///
/// Topic AL01 has the order K1, K2, K3, K4, K5, K8 and two sections (AL01-1
/// covers K1 and K3, AL01-2 covers K4); topic AL02 has the disputed K6.
///
/// Links: PPL(A) has K1 (PL010-0001), K2 (PL010-0010), K3 (PL010-0003), K4
/// (PL010-0004), K5 (PL010-0005) and no explanation for PL010-0002; PPL(H)
/// has K6 (PL010-0001), K3 and K4; SPL lacks K1 and K2 and has K3, K4, K5, K8
/// (PL010-0006); BPL has nothing.
const k1 = 'PL010-0001#a1a1a1a1';
const k2 = 'PL010-0010#b2b2b2b2';
const k3 = 'PL010-0003#c3c3c3c3';
const k4 = 'PL010-0004#d4d4d4d4';
const k5 = 'PL010-0005#e5e5e5e5';
const k6 = 'PL010-0441#0a0a0a0a';
const k8 = 'PL010-0006#f6f6f6f6';

String fixtureJson() =>
    File('test/materials/fixtures/air_law_fixture.json').readAsStringSync();

/// Serves [text] as `assets/materials/air_law.json` (a missing asset when it
/// is null) and counts the reads of every key.
class MaterialsBundle extends AssetBundle {
  MaterialsBundle([String? text]) : text = text ?? fixtureJson();

  /// A bundle without the materials asset.
  MaterialsBundle.missing() : text = null;

  final String? text;
  final Map<String, int> reads = {};

  int get materialReads => reads[materialsAssetPath(SubjectId.airLaw)] ?? 0;

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    reads[key] = (reads[key] ?? 0) + 1;
    final t = text;
    if (key != materialsAssetPath(SubjectId.airLaw) || t == null) {
      throw FlutterError('Unable to load asset: $key');
    }
    return t;
  }

  @override
  Future<ByteData> load(String key) async {
    final bytes = Uint8List.fromList(utf8.encode(await loadString(key)));
    return ByteData.sublistView(bytes);
  }
}

/// A repository over [bundle] that parses on the calling isolate.
MaterialsRepository materialsRepository(
  MaterialsBundle bundle, {
  List<String>? logs,
}) => MaterialsRepository(
  bundle: bundle,
  parser: (json, subject) async => parseMaterials(json, subject: subject),
  log: (m) => logs?.add(m),
);

/// A [Random] that makes `List.shuffle` keep the order of the list, so the
/// correct answer of the fake bank is always the first one.
class NoShuffleRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => max - 1;
}

/// Questions of air law of the fake bank of [licence].
List<Question> fakeAirLaw(Licence licence) => parseBank(
  fakeBankJson(licence),
  licence: licence,
).questionsOf(SubjectId.airLaw);

SubjectInfo fakeSubject(Licence licence) => SubjectInfo(
  licence: licence,
  id: SubjectId.airLaw,
  title: 'Air law',
  description: '',
  spec: ExamSpec.forSubject(SubjectId.airLaw, licence: licence),
  questions: fakeAirLaw(licence),
);

PracticeArgs learnArgs(Licence licence) => PracticeArgs(
  licence: licence,
  subject: SubjectId.airLaw,
  mode: PracticeMode.learn,
  questions: fakeAirLaw(licence),
);

/// Everything a materials widget test needs: fake purchases, progress in
/// memory, the fixture materials and a recorder of the paywall calls and of
/// the opened e-mails.
class MaterialsHarness {
  MaterialsHarness({
    bool premium = false,
    MaterialsBundle? bundle,
    this.email = '',
    this.mailOpens = true,
  }) : purchases = FakePurchaseService(premium: premium),
       bundle = bundle ?? MaterialsBundle();

  final FakePurchaseService purchases;
  final MaterialsBundle bundle;
  final String email;
  final bool mailOpens;
  late final ProgressRepository progress = memoryProgressRepository();

  /// Every `openPaywall` call: the trigger and `explicit`.
  final List<(PaywallTrigger, bool)> paywalls = [];
  final List<Uri> mails = [];
  final List<String> logs = [];
  late final MaterialsRepository repository = materialsRepository(
    bundle,
    logs: logs,
  );

  static void registerSetUp() {
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
  }

  List<Override> get overrides => [
    purchaseServiceProvider.overrideWithValue(purchases),
    progressRepositoryProvider.overrideWithValue(progress),
    questionBankRepositoryProvider.overrideWithValue(fakeBankRepository()),
    clockProvider.overrideWithValue(Clock.fixed(DateTime(2026, 11, 24, 12))),
    randomProvider.overrideWithValue(NoShuffleRandom()),
    materialsRepositoryProvider.overrideWithValue(repository),
    materialsReportEmailProvider.overrideWithValue(email),
    materialsMailLauncherProvider.overrideWithValue((uri) async {
      mails.add(uri);
      return mailOpens;
    }),
    paywallOpenerProvider.overrideWithValue((
      context,
      trigger, {
      explicit = false,
    }) async {
      paywalls.add((trigger, explicit));
    }),
  ];

  /// [home] in a localized app. [sized] sets a big screen (the large-font
  /// tests configure the view themselves).
  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    Locale? locale = const Locale('en'),
    bool sized = true,
  }) async {
    if (sized) {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

/// Taps the correct answer (always the first one, see [NoShuffleRandom]).
Future<void> answerCurrent(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('answer_0')));
  await tester.pumpAndSettle();
}

Future<void> nextQuestion(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('practice_next')));
  await tester.pumpAndSettle();
}

/// Answers keep the order of the bank (the first one is correct).
Override randomProviderOverride() =>
    randomProvider.overrideWithValue(NoShuffleRandom());
