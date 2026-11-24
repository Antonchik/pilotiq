import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilotiq/src/domain/access_policy.dart';
import 'package:pilotiq/src/purchases/fake_purchase_service.dart';
import 'package:pilotiq/src/purchases/paywall_launcher.dart';
import 'package:pilotiq/src/purchases/paywall_screen.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';

import 'paywall_helpers.dart';

Finder _key(String k) => find.byKey(Key(k));

void main() {
  PaywallHost.registerSetUp();

  FakePurchaseService storeLike() =>
      FakePurchaseService(offering: FakePurchaseService.storeLikeOffering);

  group('plans', () {
    testWidgets('lifetime is first and carries the best-choice label', (
      tester,
    ) async {
      final host = PaywallHost(service: storeLike());
      await host.open(tester);

      final lifetime = tester.getTopLeft(_key('paywall_plan_lifetime')).dy;
      final quarterly = tester.getTopLeft(_key('paywall_plan_quarterly')).dy;
      final monthly = tester.getTopLeft(_key('paywall_plan_monthly')).dy;
      expect(lifetime, lessThan(quarterly));
      expect(quarterly, lessThan(monthly));
      expect(find.text('Best choice'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('paywall_plan_lifetime'),
          matching: find.text('Best choice'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('prices and periods are the store ones, in English', (
      tester,
    ) async {
      await PaywallHost(service: storeLike()).open(tester);

      expect(find.text('PLN 99,99 · one-time payment'), findsOneWidget);
      expect(find.text('PLN 59,99 / 3 months'), findsOneWidget);
      expect(find.text('PLN 24,99 / month'), findsOneWidget);
      expect(find.text('Lifetime'), findsOneWidget);
      expect(find.text('3 months'), findsOneWidget);
      expect(find.text('1 month'), findsOneWidget);
    });

    testWidgets('prices and periods in Polish use the Polish plural forms', (
      tester,
    ) async {
      await PaywallHost(
        service: storeLike(),
        locale: const Locale('pl'),
      ).open(tester);

      expect(find.text('PLN 59,99 / 3 miesiące'), findsOneWidget);
      expect(find.text('PLN 24,99 / miesiąc'), findsOneWidget);
      expect(find.text('3 miesiące'), findsOneWidget);
      expect(find.text('1 miesiąc'), findsOneWidget);
      expect(find.text('PLN 99,99 · płatność jednorazowa'), findsOneWidget);
      expect(
        find.text('3 dni za darmo, potem PLN 59,99 / 3 miesiące'),
        findsOneWidget,
      );
    });

    testWidgets('a trial is mentioned only for the plan that has one', (
      tester,
    ) async {
      await PaywallHost(service: storeLike()).open(tester);

      expect(
        find.text('3 days free, then PLN 59,99 / 3 months'),
        findsOneWidget,
      );
      expect(find.textContaining('days free'), findsOneWidget);
      expect(_key('paywall_trial_notice'), findsOneWidget);
    });

    testWidgets(
      'without an introductory offer there is no word about a trial',
      (tester) async {
        final service = FakePurchaseService(
          offering: [
            for (final p in FakePurchaseService.storeLikeOffering)
              PaywallPackage(
                id: p.id,
                kind: p.kind,
                priceString: p.priceString,
                period: p.period,
              ),
          ],
        );
        await PaywallHost(service: service).open(tester);

        expect(find.textContaining('days free'), findsNothing);
        expect(find.textContaining('trial'), findsNothing);
        expect(_key('paywall_trial_notice'), findsNothing);
      },
    );

    testWidgets('a paid introductory period shows the store price', (
      tester,
    ) async {
      final service = FakePurchaseService(
        offering: const [
          PaywallPackage(
            id: 'monthly',
            kind: PackageKind.monthly,
            priceString: 'PLN 24,99',
            period: BillingPeriod(BillingUnit.month, 1),
            introOffer: IntroOffer(
              period: BillingPeriod(BillingUnit.month, 1),
              priceString: 'PLN 4,99',
            ),
          ),
        ],
      );
      await PaywallHost(service: service).open(tester);

      expect(
        find.text('1 month: PLN 4,99, then PLN 24,99 / month'),
        findsOneWidget,
      );
      // Only a free trial gets the trial notice.
      expect(_key('paywall_trial_notice'), findsNothing);
    });

    testWidgets('no plan is preselected and Continue waits for a choice', (
      tester,
    ) async {
      final host = PaywallHost(service: storeLike());
      await host.open(tester);

      expect(
        tester.widget<FilledButton>(_key('paywall_buy')).onPressed,
        isNull,
      );
      await tester.tap(_key('paywall_plan_quarterly'));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(_key('paywall_buy')).onPressed,
        isNotNull,
      );
      expect(host.service.purchasedIds, isEmpty);
    });

    testWidgets('a plan reads out its name, price and selection', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await PaywallHost(service: storeLike()).open(tester);

      SemanticsNode node(String id) =>
          tester.getSemantics(_key('paywall_plan_$id'));
      expect(
        node('quarterly').label,
        '3 months, PLN 59,99 / 3 months, 3 days free, then PLN 59,99 / 3 months, not selected',
      );
      expect(node('quarterly').flagsCollection.isSelected, Tristate.isFalse);
      expect(node('lifetime').label, contains('Best choice'));

      await tester.tap(_key('paywall_plan_quarterly'));
      await tester.pump();
      expect(node('quarterly').label, endsWith(', selected'));
      expect(node('quarterly').flagsCollection.isSelected, Tristate.isTrue);
      expect(node('lifetime').flagsCollection.isSelected, Tristate.isFalse);
      handle.dispose();
    });

    testWidgets('long prices stay readable', (tester) async {
      final service = FakePurchaseService(
        offering: FakePurchaseService.longPriceOffering,
      );
      await PaywallHost(service: service).open(tester);
      expect(find.text('PLN 99,99 / 3 months'), findsWidgets);
      expect(find.text('PLN 1 099,99 · one-time payment'), findsOneWidget);
    });
  });

  group('page', () {
    testWidgets('the close button is visible at once and closes', (
      tester,
    ) async {
      final service = FakePurchaseService()..offeringGate = Completer<void>();
      await PaywallHost(service: service).open(tester, settle: false);

      expect(_key('paywall_loading'), findsOneWidget);
      expect(_key('paywall_close'), findsOneWidget);
      await tester.tap(_key('paywall_close'));
      await tester.pumpAndSettle();
      expect(find.byType(PaywallScreen), findsNothing);
      service.offeringGate!.complete();
    });

    testWidgets('the legal links, restore and the renewal terms are there', (
      tester,
    ) async {
      await PaywallHost(service: storeLike()).open(tester);

      expect(_key('paywall_terms'), findsOneWidget);
      expect(_key('paywall_privacy'), findsOneWidget);
      expect(_key('paywall_restore'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.textContaining('renew automatically'), findsOneWidget);
      expect(
        find.textContaining('cancel in your account settings'),
        findsOneWidget,
      );
      expect(
        find.textContaining('one-time payment: it does not renew'),
        findsOneWidget,
      );
    });

    testWidgets('only one-time plans: no renewal text', (tester) async {
      final service = FakePurchaseService(
        offering: const [
          PaywallPackage(
            id: 'lifetime',
            kind: PackageKind.lifetime,
            priceString: 'PLN 99,99',
          ),
        ],
      );
      await PaywallHost(service: service).open(tester);
      expect(_key('paywall_renewal_notice'), findsNothing);
      expect(_key('paywall_one_time_notice'), findsOneWidget);
      expect(find.text('Best choice'), findsNothing);
    });

    for (final (trigger, title) in [
      (PaywallTrigger.dailyLimit, "Today's free limit is used up"),
      (PaywallTrigger.examLimit, 'The free simulation is used'),
      (PaywallTrigger.lockedFeature, 'This feature is part of Premium'),
      (PaywallTrigger.examResults, 'Topic breakdown is part of Premium'),
      (PaywallTrigger.profile, 'Pilotiq Premium'),
    ]) {
      testWidgets('the title depends on the trigger: ${trigger.name}', (
        tester,
      ) async {
        final host = PaywallHost(service: storeLike(), trigger: trigger);
        // Automatic triggers wait for 10 answers.
        await seedAnswers(host.repository, 10);
        await host.open(tester);
        expect(find.text(title), findsOneWidget);
      });
    }

    testWidgets('the limit texts use the AccessPolicy numbers', (tester) async {
      final host = PaywallHost(
        service: storeLike(),
        trigger: PaywallTrigger.dailyLimit,
      );
      await seedAnswers(host.repository, 10);
      await host.open(tester);

      expect(
        find.text(
          'Free access includes ${AccessPolicy.freeDailyAnswers} answers per day. '
          'Premium has no daily limit.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Practice without a daily limit (free: ${AccessPolicy.freeDailyAnswers} answers a day)',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Unlimited exam simulations with history and topic breakdown '
          '(free: ${AccessPolicy.freeExamsPerSubject} per subject)',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the benefits list matches what Premium unlocks', (
      tester,
    ) async {
      await PaywallHost(service: storeLike()).open(tester);
      expect(
        find.text('My mistakes: train the questions you got wrong'),
        findsOneWidget,
      );
      expect(
        find.text('Spaced repetition of the questions due for review'),
        findsOneWidget,
      );
      expect(
        find.text('Detailed readiness by subject (approximate)'),
        findsOneWidget,
      );
    });

    testWidgets('days to the exam are shown when the date is set', (
      tester,
    ) async {
      final host = PaywallHost(service: storeLike());
      await host.repository.saveSettings(
        (await host.repository.loadSettings()).copyWith(
          examDate: DateTime(2026, 12, 4),
        ),
      );
      await host.open(tester);
      expect(find.text('10 days to the exam'), findsOneWidget);
    });

    testWidgets('no exam date, no countdown', (tester) async {
      await PaywallHost(service: storeLike()).open(tester);
      expect(_key('paywall_exam_countdown'), findsNothing);
    });
  });

  group('states', () {
    testWidgets('loading, then plans', (tester) async {
      final service = storeLike()..offeringGate = Completer<void>();
      await PaywallHost(service: service).open(tester, settle: false);
      expect(_key('paywall_loading'), findsOneWidget);
      expect(_key('paywall_plan_lifetime'), findsNothing);

      service.offeringGate!.complete();
      await tester.pumpAndSettle();
      expect(_key('paywall_loading'), findsNothing);
      expect(_key('paywall_plan_lifetime'), findsOneWidget);
    });

    testWidgets('an error offers Retry, which loads again', (tester) async {
      final service = storeLike()
        ..offeringError = const PurchaseException(PurchaseFailureKind.network);
      await PaywallHost(service: service).open(tester);

      expect(_key('paywall_error'), findsOneWidget);
      expect(
        find.text('No connection. Check your internet and try again.'),
        findsOneWidget,
      );
      expect(_key('paywall_buy'), findsNothing);

      service.offeringError = null;
      await tester.tap(_key('paywall_retry'));
      await tester.pumpAndSettle();
      expect(_key('paywall_error'), findsNothing);
      expect(_key('paywall_plan_lifetime'), findsOneWidget);
      expect(service.offeringCalls, 2);
    });

    testWidgets('store errors have their own text', (tester) async {
      final service = storeLike()
        ..offeringError = const PurchaseException(PurchaseFailureKind.store);
      await PaywallHost(service: service).open(tester);
      expect(
        find.text(
          'The store could not complete the request. Please try again later.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('an empty offering shows a message with Retry', (tester) async {
      final service = FakePurchaseService(offering: const []);
      await PaywallHost(service: service).open(tester);

      expect(_key('paywall_empty'), findsOneWidget);
      expect(
        find.text('No plans are available right now. Please try again later.'),
        findsOneWidget,
      );
      service.offering = FakePurchaseService.storeLikeOffering;
      await tester.tap(_key('paywall_retry'));
      await tester.pumpAndSettle();
      expect(_key('paywall_plan_lifetime'), findsOneWidget);
    });

    testWidgets('a build without keys says that purchases are unavailable', (
      tester,
    ) async {
      final service = FakePurchaseService(isAvailable: false);
      await PaywallHost(service: service).open(tester);

      expect(_key('paywall_unavailable'), findsOneWidget);
      expect(
        find.text('Purchases are not available in this build of the app.'),
        findsOneWidget,
      );
      expect(_key('paywall_buy'), findsNothing);
      expect(_key('paywall_restore'), findsNothing);
      expect(service.offeringCalls, 0);
      // Still closable, with the legal links.
      expect(_key('paywall_close'), findsOneWidget);
      expect(_key('paywall_terms'), findsOneWidget);
    });
  });

  group('purchase', () {
    Future<void> choose(WidgetTester tester, String id) async {
      await tester.tap(_key('paywall_plan_$id'));
      await tester.pump();
    }

    testWidgets('buying lifetime thanks the user and unlocks Premium', (
      tester,
    ) async {
      final host = PaywallHost(service: storeLike());
      await host.open(tester);
      await choose(tester, 'lifetime');
      await tester.tap(_key('paywall_buy'));
      await tester.pumpAndSettle();

      expect(host.service.purchasedIds, ['lifetime']);
      expect(find.text('Thank you!'), findsOneWidget);
      expect(_key('paywall_plan_lifetime'), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PaywallScreen)),
      );
      expect(container.read(isPremiumProvider), isTrue);

      await tester.tap(_key('paywall_done'));
      await tester.pumpAndSettle();
      expect(find.byType(PaywallScreen), findsNothing);
    });

    testWidgets(
      'while buying every action is off and a second tap is ignored',
      (tester) async {
        final service = storeLike()..purchaseGate = Completer<void>();
        final host = PaywallHost(service: service);
        await host.open(tester);
        await choose(tester, 'quarterly');

        await tester.tap(_key('paywall_buy'));
        await tester.pump();
        expect(_key('paywall_purchasing'), findsOneWidget);
        expect(
          tester.widget<FilledButton>(_key('paywall_buy')).onPressed,
          isNull,
        );
        expect(
          tester.widget<TextButton>(_key('paywall_restore')).onPressed,
          isNull,
        );
        await tester.tap(_key('paywall_buy'), warnIfMissed: false);
        await tester.tap(_key('paywall_plan_lifetime'), warnIfMissed: false);
        await tester.pump();
        expect(service.purchasedIds, ['quarterly']);
        // The close button keeps working.
        expect(_key('paywall_close'), findsOneWidget);

        service.purchaseGate!.complete();
        await tester.pumpAndSettle();
        expect(service.purchasedIds, ['quarterly']);
        expect(find.text('Thank you!'), findsOneWidget);
      },
    );

    testWidgets('cancelling is silent: no message, plans stay', (tester) async {
      final service = storeLike()..purchaseOutcome = PurchaseOutcome.cancelled;
      await PaywallHost(service: service).open(tester);
      await choose(tester, 'monthly');
      await tester.tap(_key('paywall_buy'));
      await tester.pumpAndSettle();

      expect(_key('paywall_action_error'), findsNothing);
      expect(_key('paywall_pending'), findsNothing);
      expect(find.text('Thank you!'), findsNothing);
      expect(_key('paywall_plan_monthly'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(_key('paywall_buy')).onPressed,
        isNotNull,
      );
      expect(service.current.isPremium, isFalse);
    });

    testWidgets('a pending payment explains itself and grants nothing', (
      tester,
    ) async {
      final service = storeLike()..purchaseOutcome = PurchaseOutcome.pending;
      await PaywallHost(service: service).open(tester);
      await choose(tester, 'lifetime');
      await tester.tap(_key('paywall_buy'));
      await tester.pumpAndSettle();

      expect(_key('paywall_pending'), findsOneWidget);
      expect(find.textContaining('waiting for approval'), findsOneWidget);
      expect(find.text('Thank you!'), findsNothing);
      expect(service.current.isPremium, isFalse);
    });

    testWidgets('a store error shows a message with Retry that buys again', (
      tester,
    ) async {
      final service = storeLike()
        ..purchaseError = const PurchaseException(PurchaseFailureKind.store);
      await PaywallHost(service: service).open(tester);
      await choose(tester, 'lifetime');
      await tester.tap(_key('paywall_buy'));
      await tester.pumpAndSettle();

      expect(_key('paywall_action_error'), findsOneWidget);
      expect(service.current.isPremium, isFalse);

      service.purchaseError = null;
      await tester.tap(_key('paywall_retry'));
      await tester.pumpAndSettle();
      expect(service.purchasedIds, ['lifetime', 'lifetime']);
      expect(find.text('Thank you!'), findsOneWidget);
    });

    testWidgets('a payment that is not active says so and points to Restore', (
      tester,
    ) async {
      final service = storeLike()
        ..purchaseError = const PurchaseException(
          PurchaseFailureKind.notActivated,
        );
      await PaywallHost(service: service).open(tester);
      await choose(tester, 'lifetime');
      await tester.tap(_key('paywall_buy'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Restore purchases'), findsWidgets);
      expect(find.textContaining('Premium is not active yet'), findsOneWidget);
    });

    testWidgets('closing during a purchase does not crash when it ends', (
      tester,
    ) async {
      final service = storeLike()..purchaseGate = Completer<void>();
      await PaywallHost(service: service).open(tester);
      await choose(tester, 'lifetime');
      await tester.tap(_key('paywall_buy'));
      await tester.pump();
      await tester.tap(_key('paywall_close'));
      await tester.pumpAndSettle();
      service.purchaseGate!.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(service.current.isPremium, isTrue);
    });
  });

  group('restore', () {
    testWidgets('with an active purchase: thanks and Premium', (tester) async {
      final service = storeLike();
      await PaywallHost(service: service).open(tester);
      await tester.tap(_key('paywall_restore'));
      await tester.pumpAndSettle();

      expect(service.restoreCalls, 1);
      expect(find.text('Thank you!'), findsOneWidget);
      expect(service.current.isPremium, isTrue);
    });

    testWidgets('without purchases: a plain message', (tester) async {
      final service = storeLike()..restoreFindsPremium = false;
      await PaywallHost(service: service).open(tester);
      await tester.tap(_key('paywall_restore'));
      await tester.pumpAndSettle();

      expect(_key('paywall_restore_none'), findsOneWidget);
      expect(
        find.text('No active purchases were found for this store account.'),
        findsOneWidget,
      );
      expect(_key('paywall_action_error'), findsNothing);
    });

    testWidgets('a failure shows Retry', (tester) async {
      final service = storeLike()
        ..restoreError = const PurchaseException(PurchaseFailureKind.network);
      await PaywallHost(service: service).open(tester);
      await tester.tap(_key('paywall_restore'));
      await tester.pumpAndSettle();
      expect(_key('paywall_action_error'), findsOneWidget);

      service.restoreError = null;
      await tester.tap(_key('paywall_retry'));
      await tester.pumpAndSettle();
      expect(find.text('Thank you!'), findsOneWidget);
    });
  });

  group('premium state', () {
    testWidgets('an active Premium user sees a note, not the offer', (
      tester,
    ) async {
      final service = FakePurchaseService(
        premium: true,
        offering: FakePurchaseService.storeLikeOffering,
      );
      await PaywallHost(service: service).open(tester);
      expect(find.text('Premium is active'), findsOneWidget);
      expect(_key('paywall_plan_lifetime'), findsNothing);
    });

    testWidgets('Premium that appears while the paywall is open (an approved '
        'pending payment) switches the page to the thanks', (tester) async {
      final service = storeLike();
      await PaywallHost(service: service).open(tester);
      service.setEntitlement(const EntitlementState(isPremium: true));
      await tester.pumpAndSettle();
      expect(find.text('Thank you!'), findsOneWidget);
      expect(_key('paywall_plan_lifetime'), findsNothing);
    });
  });
}
