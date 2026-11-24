import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilotiq/src/purchases/purchase_config.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';
import 'package:pilotiq/src/purchases/purchases_flutter_gateway.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;

const _context = rc.PresentedOfferingContext('default', null, null);

rc.CustomerInfo _info({rc.EntitlementInfo? premium, bool listed = true}) =>
    rc.CustomerInfo(
      rc.EntitlementInfos(
        {if (premium != null) premium.identifier: premium},
        {if (premium != null && listed && premium.isActive) premium.identifier: premium},
      ),
      const {},
      const [],
      const [],
      const [],
      '',
      '',
      const {},
      '2026-11-24T12:00:00Z',
    );

rc.EntitlementInfo _entitlement({
  String id = 'premium',
  bool active = true,
  String? expires,
}) => rc.EntitlementInfo(
  id,
  active,
  true,
  '2026-11-01T00:00:00Z',
  '2026-11-01T00:00:00Z',
  'product',
  false,
  expirationDate: expires,
);

rc.StoreProduct _product({
  String id = 'p',
  String? period,
  rc.IntroductoryPrice? intro,
  rc.SubscriptionOption? option,
  bool subscription = true,
  String price = 'PLN 59,99',
}) => rc.StoreProduct(
  id,
  '',
  'Title of $id',
  59.99,
  price,
  'PLN',
  introductoryPrice: intro,
  productCategory: subscription
      ? rc.ProductCategory.subscription
      : rc.ProductCategory.nonSubscription,
  subscriptionPeriod: period,
  defaultOption: option,
);

rc.Package _package(
  rc.StoreProduct product, {
  rc.PackageType type = rc.PackageType.threeMonth,
  String id = 'quarterly',
}) => rc.Package(id, type, product, _context);

rc.PricingPhase _phase(
  rc.PeriodUnit unit,
  int value, {
  int cycles = 1,
  num micros = 0,
  String formatted = 'PLN 0,00',
}) => rc.PricingPhase(
  rc.Period(unit, value, 'P$value'),
  rc.RecurrenceMode.finiteRecurring,
  cycles,
  rc.Price(formatted, micros.round(), 'PLN'),
  rc.OfferPaymentMode.freeTrial,
);

rc.SubscriptionOption _option({
  rc.PricingPhase? free,
  rc.PricingPhase? intro,
}) => rc.SubscriptionOption(
  'opt',
  'p:base',
  'p',
  const [],
  const [],
  true,
  null,
  false,
  null,
  free,
  intro,
  null,
  null,
);

void main() {
  group('ISO periods', () {
    test('are parsed to unit and count', () {
      expect(BillingPeriod.tryParseIso('P3M'), const BillingPeriod(BillingUnit.month, 3));
      expect(BillingPeriod.tryParseIso('P1W'), const BillingPeriod(BillingUnit.week, 1));
      expect(BillingPeriod.tryParseIso('P7D'), const BillingPeriod(BillingUnit.day, 7));
      expect(BillingPeriod.tryParseIso('P1Y'), const BillingPeriod(BillingUnit.year, 1));
    });

    test('anything else is unknown, never a wrong period', () {
      for (final v in [null, '', 'P1Y6M', 'PT5H', 'P0M', '3 months', 'P-1M']) {
        expect(BillingPeriod.tryParseIso(v), isNull, reason: '$v');
      }
    });
  });

  group('customer info', () {
    test('an active premium entitlement without end is lifetime', () {
      final e = mapCustomerInfo(_info(premium: _entitlement()));
      expect(e.isActive, isTrue);
      expect(e.expiresAt, isNull);
    });

    test('the end date of a subscription is kept', () {
      final e = mapCustomerInfo(
        _info(premium: _entitlement(expires: '2026-12-31T08:00:00Z')),
      );
      expect(e.expiresAt!.isAtSameMomentAs(DateTime.utc(2026, 12, 31, 8)), isTrue);
    });

    test('an inactive or missing entitlement is not premium', () {
      expect(mapCustomerInfo(_info(premium: _entitlement(active: false))).isActive, isFalse);
      expect(mapCustomerInfo(_info()).isActive, isFalse);
    });

    test('another entitlement id does not unlock Premium', () {
      expect(
        mapCustomerInfo(_info(premium: _entitlement(id: 'other'))).isActive,
        isFalse,
      );
      expect(premiumEntitlementId, 'premium');
    });
  });

  group('errors', () {
    PlatformException coded(rc.PurchasesErrorCode c) =>
        PlatformException(code: '${c.index}');

    test('network, store and other errors are told apart', () {
      expect(
        mapPurchasesError(coded(rc.PurchasesErrorCode.networkError)).kind,
        PurchaseFailureKind.network,
      );
      expect(
        mapPurchasesError(coded(rc.PurchasesErrorCode.offlineConnectionError)).kind,
        PurchaseFailureKind.network,
      );
      expect(
        mapPurchasesError(coded(rc.PurchasesErrorCode.storeProblemError)).kind,
        PurchaseFailureKind.store,
      );
      expect(
        mapPurchasesError(coded(rc.PurchasesErrorCode.configurationError)).kind,
        PurchaseFailureKind.unknown,
      );
      expect(mapPurchasesError(StateError('x')).kind, PurchaseFailureKind.unknown);
    });
  });

  group('offering', () {
    test('package kinds follow the RevenueCat package types', () {
      PackageKind kind(rc.PackageType t) => mapPackage(
        _package(_product(period: 'P1M'), type: t),
        platform: TargetPlatform.android,
      ).kind;
      expect(kind(rc.PackageType.lifetime), PackageKind.lifetime);
      expect(kind(rc.PackageType.threeMonth), PackageKind.quarterly);
      expect(kind(rc.PackageType.monthly), PackageKind.monthly);
      expect(kind(rc.PackageType.annual), PackageKind.other);
    });

    test('price and period are taken from the store product', () {
      final p = mapPackage(
        _package(_product(period: 'P3M', price: 'PLN 99,99')),
        platform: TargetPlatform.android,
      );
      expect(p.priceString, 'PLN 99,99');
      expect(p.period, const BillingPeriod(BillingUnit.month, 3));
      expect(p.isSubscription, isTrue);
      expect(p.id, 'quarterly');
    });

    test('a lifetime product is a one-time payment without period', () {
      final p = mapPackage(
        _package(
          _product(subscription: false),
          type: rc.PackageType.lifetime,
          id: 'lifetime',
        ),
        platform: TargetPlatform.iOS,
        eligibility: rc.IntroEligibilityStatus.introEligibilityStatusEligible,
      );
      expect(p.isSubscription, isFalse);
      expect(p.period, isNull);
      expect(p.introOffer, isNull);
    });

    test('no current offering gives an empty list', () {
      expect(
        mapOffering(const rc.Offerings({}), platform: TargetPlatform.android),
        isEmpty,
      );
    });

    test('the packages of the current offering are mapped in order', () {
      final offering = rc.Offering('default', '', const {}, [
        _package(_product(id: 'a', period: 'P1M'), type: rc.PackageType.monthly, id: 'monthly'),
        _package(_product(id: 'b', subscription: false), type: rc.PackageType.lifetime, id: 'lifetime'),
      ]);
      final result = mapOffering(
        rc.Offerings({'default': offering}, current: offering),
        platform: TargetPlatform.android,
      );
      expect([for (final p in result) p.id], ['monthly', 'lifetime']);
    });
  });

  group('introductory offer', () {
    final iosTrial = rc.IntroductoryPrice(
      0,
      'PLN 0,00',
      'P3D',
      1,
      rc.PeriodUnit.day,
      3,
    );

    test('iOS: a free trial only when the user is eligible', () {
      final product = _product(period: 'P3M', intro: iosTrial);
      final eligible = mapIntroOffer(
        product,
        platform: TargetPlatform.iOS,
        eligibility: rc.IntroEligibilityStatus.introEligibilityStatusEligible,
      );
      expect(eligible!.isFree, isTrue);
      expect(eligible.period, const BillingPeriod(BillingUnit.day, 3));

      for (final status in [
        rc.IntroEligibilityStatus.introEligibilityStatusIneligible,
        rc.IntroEligibilityStatus.introEligibilityStatusUnknown,
        rc.IntroEligibilityStatus.introEligibilityStatusNoIntroOfferExists,
        null,
      ]) {
        expect(
          mapIntroOffer(product, platform: TargetPlatform.iOS, eligibility: status),
          isNull,
          reason: '$status',
        );
      }
    });

    test('iOS: a reduced first period keeps its price; several cycles are left out', () {
      final paid = mapIntroOffer(
        _product(
          period: 'P1M',
          intro: rc.IntroductoryPrice(4.99, 'PLN 4,99', 'P1M', 1, rc.PeriodUnit.month, 1),
        ),
        platform: TargetPlatform.iOS,
        eligibility: rc.IntroEligibilityStatus.introEligibilityStatusEligible,
      );
      expect(paid!.isFree, isFalse);
      expect(paid.priceString, 'PLN 4,99');

      expect(
        mapIntroOffer(
          _product(
            period: 'P1M',
            intro: rc.IntroductoryPrice(4.99, 'PLN 4,99', 'P1M', 3, rc.PeriodUnit.month, 1),
          ),
          platform: TargetPlatform.iOS,
          eligibility: rc.IntroEligibilityStatus.introEligibilityStatusEligible,
        ),
        isNull,
      );
    });

    test('Android: the free phase of the default option is the trial', () {
      final product = _product(
        period: 'P3M',
        option: _option(free: _phase(rc.PeriodUnit.day, 3)),
      );
      final trial = mapIntroOffer(product, platform: TargetPlatform.android);
      expect(trial!.isFree, isTrue);
      expect(trial.period, const BillingPeriod(BillingUnit.day, 3));
    });

    test('Android: no offer, or a trial followed by a reduced price, says nothing', () {
      expect(
        mapIntroOffer(
          _product(period: 'P3M', option: _option()),
          platform: TargetPlatform.android,
        ),
        isNull,
      );
      expect(
        mapIntroOffer(
          _product(period: 'P3M'),
          platform: TargetPlatform.android,
        ),
        isNull,
      );
      expect(
        mapIntroOffer(
          _product(
            period: 'P3M',
            option: _option(
              free: _phase(rc.PeriodUnit.day, 3),
              intro: _phase(rc.PeriodUnit.month, 1, micros: 4990000, formatted: 'PLN 4,99'),
            ),
          ),
          platform: TargetPlatform.android,
        ),
        isNull,
      );
    });

    test('a product without any offer maps to no trial on both platforms', () {
      final product = _product(period: 'P1M');
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        expect(
          mapPackage(
            _package(product),
            platform: platform,
            eligibility: rc.IntroEligibilityStatus.introEligibilityStatusEligible,
          ).introOffer,
          isNull,
        );
      }
    });
  });

  group('keys', () {
    test('the key of a platform comes from its own define', () {
      expect(
        revenueCatKeyFor(TargetPlatform.android, androidKey: 'a', iosKey: 'i'),
        'a',
      );
      expect(
        revenueCatKeyFor(TargetPlatform.iOS, androidKey: 'a', iosKey: 'i'),
        'i',
      );
      expect(
        revenueCatKeyFor(TargetPlatform.linux, androidKey: 'a', iosKey: 'i'),
        '',
      );
    });

    test('this test build has no keys', () {
      expect(currentRevenueCatKey(), isEmpty);
    });
  });
}
