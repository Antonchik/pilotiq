import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/progress/progress_repository.dart';
import 'package:pilotiq/src/progress/providers.dart';
import 'package:pilotiq/src/purchases/fake_purchase_service.dart';
import 'package:pilotiq/src/purchases/paywall_launcher.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';

import '../bank/memory_hive.dart';

/// 2026-11-24 12:00 local time.
final DateTime paywallTestNow = DateTime(2026, 11, 24, 12);

/// A host app with a button that opens the paywall through the real
/// `openPaywall` (so the launcher rules apply), over in-memory boxes.
class PaywallHost {
  PaywallHost({
    FakePurchaseService? service,
    ProgressRepository? repository,
    this.trigger = PaywallTrigger.profile,
    this.locale = const Locale('en'),
    this.textScale = 1,
    this.size = const Size(1080, 2400),
  }) : service = service ?? FakePurchaseService(),
       repository = repository ?? memoryProgressRepository();

  final FakePurchaseService service;
  final ProgressRepository repository;

  /// What the launcher logged.
  final List<String> logs = [];
  final PaywallTrigger trigger;
  final Locale locale;
  final double textScale;
  final Size size;

  static void registerSetUp() {
    setUp(() async {
      await openMemoryBox('config');
    });
    tearDown(() async {
      await Hive.close();
    });
  }

  List<Override> get overrides => [
    purchaseServiceProvider.overrideWithValue(service),
    progressRepositoryProvider.overrideWithValue(repository),
    clockProvider.overrideWithValue(Clock.fixed(paywallTestNow)),
    paywallLogProvider.overrideWithValue(logs.add),
  ];

  Widget app({Widget? home, List<Override> extra = const []}) => ProviderScope(
    overrides: [...overrides, ...extra],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home:
          home ??
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open_paywall'),
                  onPressed: () => openPaywall(context, trigger: trigger),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
    ),
  );

  void configureView(WidgetTester tester) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearAllTestValues();
    });
  }

  /// Pumps the host and opens the paywall.
  Future<void> open(WidgetTester tester, {bool settle = true}) async {
    configureView(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open_paywall')));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
    }
  }
}

/// Seeds [count] answers, so that automatic triggers are allowed.
Future<void> seedAnswers(ProgressRepository repo, int count) async {
  for (var i = 0; i < count; i++) {
    await repo.recordAnswer(Licence.ppla, 'q$i', true, paywallTestNow);
  }
}
