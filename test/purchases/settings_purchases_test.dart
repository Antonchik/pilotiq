import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilotiq/src/purchases/fake_purchase_service.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';
import 'package:pilotiq/src/settings/settings_screen.dart';

import 'paywall_helpers.dart';

Finder _key(String k) => find.byKey(Key(k));

void main() {
  PaywallHost.registerSetUp();

  Future<void> pumpSettings(WidgetTester tester, PaywallHost host) async {
    host.configureView(tester);
    await tester.pumpWidget(host.app(home: const SettingsScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('"Restore purchases" restores and confirms', (tester) async {
    final host = PaywallHost();
    await pumpSettings(tester, host);

    await tester.ensureVisible(_key('settings_restore_purchases'));
    await tester.tap(_key('settings_restore_purchases'));
    await tester.pumpAndSettle();

    expect(host.service.restoreCalls, 1);
    expect(host.service.current.isPremium, isTrue);
    expect(find.text('Premium restored'), findsOneWidget);
  });

  testWidgets('nothing to restore is said plainly', (tester) async {
    final service = FakePurchaseService()..restoreFindsPremium = false;
    await pumpSettings(tester, PaywallHost(service: service));

    await tester.ensureVisible(_key('settings_restore_purchases'));
    await tester.tap(_key('settings_restore_purchases'));
    await tester.pumpAndSettle();
    expect(
      find.text('No active purchases were found for this store account.'),
      findsOneWidget,
    );
  });

  testWidgets('a failed restore offers Retry', (tester) async {
    final service = FakePurchaseService()
      ..restoreError = const PurchaseException(PurchaseFailureKind.network);
    await pumpSettings(tester, PaywallHost(service: service));

    await tester.ensureVisible(_key('settings_restore_purchases'));
    await tester.tap(_key('settings_restore_purchases'));
    await tester.pumpAndSettle();
    expect(
      find.text('No connection. Check your internet and try again.'),
      findsOneWidget,
    );
    service.restoreError = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(service.restoreCalls, 2);
    expect(service.current.isPremium, isTrue);
  });

  testWidgets('without store keys the tile is off and says why', (
    tester,
  ) async {
    final service = FakePurchaseService(isAvailable: false);
    await pumpSettings(tester, PaywallHost(service: service));

    await tester.ensureVisible(_key('settings_restore_purchases'));
    expect(
      find.text('Not available in this build of the app.'),
      findsOneWidget,
    );
    await tester.tap(_key('settings_restore_purchases'));
    await tester.pumpAndSettle();
    expect(service.restoreCalls, 0);
  });

  testWidgets('the settings say where to cancel a subscription', (
    tester,
  ) async {
    await pumpSettings(tester, PaywallHost());
    await tester.ensureVisible(_key('settings_manage_subscription'));
    expect(
      find.text(
        'To cancel or change a subscription, open the subscriptions of your Google Play account.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the Premium card opens the paywall', (tester) async {
    final host = PaywallHost(
      service: FakePurchaseService(
        offering: FakePurchaseService.storeLikeOffering,
      ),
    );
    await pumpSettings(tester, host);
    await tester.tap(_key('settings_premium'));
    await tester.pumpAndSettle();
    expect(_key('paywall_plan_lifetime'), findsOneWidget);
  });
}
