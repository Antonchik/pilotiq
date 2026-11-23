import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pilotiq/src/app.dart';
import 'package:pilotiq/src/bank/question_bank_repository.dart';
import 'package:pilotiq/src/progress/progress_repository.dart';
import 'package:pilotiq/src/progress/providers.dart';
import 'package:pilotiq/src/purchases/fake_purchase_service.dart';
import 'package:pilotiq/src/purchases/paywall_launcher.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';

import '../bank/fake_bank.dart';
import '../bank/memory_hive.dart';

/// 2026-11-23 12:00 local time.
final DateTime testNow = DateTime(2026, 11, 23, 12);

/// Common set-up of the dashboard / settings / onboarding widget tests: the
/// boxes live in memory, the clock is fixed, the bank is the fake one.
class AppHarness {
  AppHarness({
    bool premium = false,
    ProgressRepository? repository,
    QuestionBankRepository? bank,
    DateTime? now,
  }) : repository = repository ?? memoryProgressRepository(),
       bank = bank ?? fakeBankRepository(),
       now = now ?? testNow,
       purchases = FakePurchaseService(premium: premium);

  final ProgressRepository repository;
  final QuestionBankRepository bank;
  final DateTime now;
  final FakePurchaseService purchases;
  final List<PaywallTrigger> paywalls = [];

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

  /// Marks the onboarding as done (and optionally sets more settings).
  Future<void> seedConfig([Map<String, Object?> values = const {}]) async {
    final config = Hive.box<dynamic>('config');
    await config.put('onboardingDone', true);
    for (final e in values.entries) {
      await config.put(e.key, e.value);
    }
  }

  List<Override> get overrides => [
    purchaseServiceProvider.overrideWithValue(purchases),
    progressRepositoryProvider.overrideWithValue(repository),
    questionBankRepositoryProvider.overrideWithValue(bank),
    clockProvider.overrideWithValue(Clock.fixed(now)),
    paywallOpenerProvider.overrideWithValue((context, trigger) async {
      paywalls.add(trigger);
    }),
  ];

  Future<void> pump(
    WidgetTester tester, {
    List<Override> extraOverrides = const [],
  }) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...overrides, ...extraOverrides],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();
  }
}
