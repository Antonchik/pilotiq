import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/purchases/fake_purchase_service.dart';
import 'package:pilotiq/src/purchases/paywall_launcher.dart';
import 'package:pilotiq/src/purchases/paywall_screen.dart';

import 'paywall_helpers.dart';

void main() {
  PaywallHost.registerSetUp();

  FakePurchaseService service() =>
      FakePurchaseService(offering: FakePurchaseService.storeLikeOffering);

  group('automatic triggers wait for about 10 answers', () {
    for (final trigger in [
      PaywallTrigger.dailyLimit,
      PaywallTrigger.examLimit,
    ]) {
      testWidgets('${trigger.name}: 5 answers in total do not open it', (
        tester,
      ) async {
        final host = PaywallHost(service: service(), trigger: trigger);
        await seedAnswers(host.repository, 5);
        await host.open(tester);
        expect(find.byType(PaywallScreen), findsNothing);
        expect(
          host.logs.where(
            (l) => l.contains('paywall: ${trigger.name} not shown yet'),
          ),
          hasLength(1),
        );
      });

      testWidgets('${trigger.name}: 9 answers still do not, 10 do', (
        tester,
      ) async {
        final host = PaywallHost(service: service(), trigger: trigger);
        await seedAnswers(host.repository, 9);
        await host.open(tester);
        expect(find.byType(PaywallScreen), findsNothing);

        await seedAnswers(host.repository, 10);
        await tester.tap(find.byKey(const Key('open_paywall')));
        await tester.pumpAndSettle();
        expect(find.byType(PaywallScreen), findsOneWidget);
      });
    }

    testWidgets('answers of exam simulations count too', (tester) async {
      final host = PaywallHost(
        service: service(),
        trigger: PaywallTrigger.dailyLimit,
      );
      for (var i = 0; i < 10; i++) {
        await host.repository.recordAnswer(
          Licence.ppla,
          'e$i',
          true,
          paywallTestNow,
          countsTowardDailyLimit: false,
        );
      }
      await host.open(tester);
      expect(find.byType(PaywallScreen), findsOneWidget);
    });

    testWidgets('answers of earlier days count', (tester) async {
      final host = PaywallHost(
        service: service(),
        trigger: PaywallTrigger.dailyLimit,
      );
      for (var d = 1; d <= 5; d++) {
        for (var i = 0; i < 2; i++) {
          await host.repository.recordAnswer(
            Licence.ppla,
            'q$d$i',
            true,
            paywallTestNow.subtract(Duration(days: d)),
          );
        }
      }
      await host.open(tester);
      expect(find.byType(PaywallScreen), findsOneWidget);
    });
  });

  group('explicit actions always open it', () {
    for (final trigger in [
      PaywallTrigger.profile,
      PaywallTrigger.lockedFeature,
      PaywallTrigger.examResults,
    ]) {
      testWidgets('${trigger.name} with no answers at all', (tester) async {
        final host = PaywallHost(service: service(), trigger: trigger);
        await host.open(tester);
        expect(find.byType(PaywallScreen), findsOneWidget);
      });
    }
  });

  testWidgets('every trigger is logged, also a suppressed one', (tester) async {
    final host = PaywallHost(
      service: service(),
      trigger: PaywallTrigger.dailyLimit,
    );
    await host.open(tester);
    expect(host.logs, contains('paywall: trigger dailyLimit'));
  });

  testWidgets('a second request while the paywall is open is ignored', (
    tester,
  ) async {
    final host = PaywallHost(service: service());
    host.configureView(tester);
    await tester.pumpWidget(host.app());
    await tester.pumpAndSettle();
    final context = tester.element(find.byKey(const Key('open_paywall')));
    openPaywall(context, trigger: PaywallTrigger.profile).ignore();
    openPaywall(context, trigger: PaywallTrigger.lockedFeature).ignore();
    await tester.pumpAndSettle();
    expect(find.byType(PaywallScreen), findsOneWidget);

    // After closing, it can be opened again.
    await tester.tap(find.byKey(const Key('paywall_close')));
    await tester.pumpAndSettle();
    openPaywall(context, trigger: PaywallTrigger.profile).ignore();
    await tester.pumpAndSettle();
    expect(find.byType(PaywallScreen), findsOneWidget);
  });

  test('which triggers are automatic', () {
    expect(PaywallTrigger.dailyLimit.isAutomatic, isTrue);
    expect(PaywallTrigger.examLimit.isAutomatic, isTrue);
    expect(PaywallTrigger.profile.isAutomatic, isFalse);
    expect(PaywallTrigger.lockedFeature.isAutomatic, isFalse);
    expect(PaywallTrigger.examResults.isAutomatic, isFalse);
    expect(paywallMinAnswers, 10);
  });
}
