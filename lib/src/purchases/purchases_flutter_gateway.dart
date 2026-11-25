import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:pilotiq/src/purchases/purchase_config.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';
import 'package:pilotiq/src/purchases/purchases_gateway.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;

/// Entitlement `premium` of [info]. A lifetime purchase has no expiration.
ServerEntitlement mapCustomerInfo(rc.CustomerInfo info) {
  final serverTime = DateTime.tryParse(info.requestDate)?.toLocal();
  final entitlement = info.entitlements.active[premiumEntitlementId];
  if (entitlement == null || !entitlement.isActive) {
    return ServerEntitlement(isActive: false, serverTime: serverTime);
  }
  final end = entitlement.expirationDate;
  return ServerEntitlement(
    isActive: true,
    serverTime: serverTime,
    expiresAt: end == null ? null : DateTime.tryParse(end)?.toLocal(),
  );
}

/// Error of the store SDK as the app's [PurchaseException].
PurchaseException mapPurchasesError(Object error) {
  if (error is PurchaseException) return error;
  if (error is! PlatformException) {
    return PurchaseException(PurchaseFailureKind.unknown, '$error');
  }
  final kind = switch (rc.PurchasesErrorHelper.getErrorCode(error)) {
    rc.PurchasesErrorCode.networkError ||
    rc.PurchasesErrorCode.offlineConnectionError ||
    rc.PurchasesErrorCode.apiEndpointBlocked ||
    rc.PurchasesErrorCode.productRequestTimeout => PurchaseFailureKind.network,
    rc.PurchasesErrorCode.storeProblemError ||
    rc.PurchasesErrorCode.purchaseNotAllowedError ||
    rc.PurchasesErrorCode.purchaseInvalidError ||
    rc.PurchasesErrorCode.productNotAvailableForPurchaseError ||
    rc.PurchasesErrorCode.ineligibleError => PurchaseFailureKind.store,
    _ => PurchaseFailureKind.unknown,
  };
  return PurchaseException(kind, error.code);
}

BillingUnit? _unit(rc.PeriodUnit unit) => switch (unit) {
  rc.PeriodUnit.day => BillingUnit.day,
  rc.PeriodUnit.week => BillingUnit.week,
  rc.PeriodUnit.month => BillingUnit.month,
  rc.PeriodUnit.year => BillingUnit.year,
  rc.PeriodUnit.unknown => null,
};

/// The introductory offer of [product] that the user can really get, or null.
///
/// iOS: only when the store says the user is eligible (unknown counts as not
/// eligible, as the plugin documentation advises). Android: the default
/// subscription option of the product already is the offer the user gets, so
/// its free phase is the trial. Offers made of several phases (a trial followed
/// by a reduced price) and offers with several cycles are not described: the
/// system purchase sheet shows their terms.
IntroOffer? mapIntroOffer(
  rc.StoreProduct product, {
  required TargetPlatform platform,
  rc.IntroEligibilityStatus? eligibility,
}) {
  if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
    if (eligibility !=
        rc.IntroEligibilityStatus.introEligibilityStatusEligible) {
      return null;
    }
    final intro = product.introductoryPrice;
    final unit = intro == null ? null : _unit(intro.periodUnit);
    if (intro == null ||
        unit == null ||
        intro.cycles != 1 ||
        intro.periodNumberOfUnits <= 0) {
      return null;
    }
    return IntroOffer(
      period: BillingPeriod(unit, intro.periodNumberOfUnits),
      priceString: intro.price == 0 ? null : intro.priceString,
    );
  }
  final option = product.defaultOption;
  if (option == null) return null;
  final free = option.freePhase;
  final paid = option.introPhase;
  if (free != null && paid != null) return null;
  final phase = free ?? paid;
  final period = phase?.billingPeriod;
  if (phase == null || period == null || (phase.billingCycleCount ?? 1) != 1) {
    return null;
  }
  final unit = _unit(period.unit);
  if (unit == null || period.value <= 0) return null;
  return IntroOffer(
    period: BillingPeriod(unit, period.value),
    priceString: free != null ? null : phase.price.formatted,
  );
}

PaywallPackage mapPackage(
  rc.Package package, {
  required TargetPlatform platform,
  rc.IntroEligibilityStatus? eligibility,
}) {
  final product = package.storeProduct;
  // A prepaid plan (Google Play) is paid once and does not renew: it is
  // shown as a one-time payment for a period, without the auto-renewal text.
  final prepaid = product.defaultOption?.isPrepaid ?? false;
  final subscription =
      !prepaid &&
      (product.productCategory == rc.ProductCategory.subscription ||
          product.subscriptionPeriod != null);
  return PaywallPackage(
    id: package.identifier,
    kind: switch (package.packageType) {
      rc.PackageType.lifetime => PackageKind.lifetime,
      rc.PackageType.monthly => PackageKind.monthly,
      rc.PackageType.threeMonth => PackageKind.quarterly,
      _ => PackageKind.other,
    },
    priceString: product.priceString,
    period: subscription
        ? BillingPeriod.tryParseIso(product.subscriptionPeriod)
        : prepaid
        ? _prepaidPeriod(product)
        : null,
    introOffer: subscription
        ? mapIntroOffer(product, platform: platform, eligibility: eligibility)
        : null,
    title: product.title,
    isSubscription: subscription,
  );
}

/// How long a prepaid plan gives access: the period of its (only) pricing
/// phase, else of the option, else of the product. Null when none is a plain
/// period the paywall can name.
BillingPeriod? _prepaidPeriod(rc.StoreProduct product) {
  final option = product.defaultOption;
  final period = option?.fullPricePhase?.billingPeriod ?? option?.billingPeriod;
  final unit = period == null ? null : _unit(period.unit);
  if (period != null && unit != null && period.value > 0) {
    return BillingPeriod(unit, period.value);
  }
  return BillingPeriod.tryParseIso(product.subscriptionPeriod);
}

/// Packages of the current offering; empty when there is none.
List<PaywallPackage> mapOffering(
  rc.Offerings offerings, {
  required TargetPlatform platform,
  Map<String, rc.IntroEligibilityStatus> eligibility = const {},
}) {
  final current = offerings.current;
  if (current == null) return const [];
  return [
    for (final p in current.availablePackages)
      mapPackage(
        p,
        platform: platform,
        eligibility: eligibility[p.storeProduct.identifier],
      ),
  ];
}

/// The real [PurchasesGateway]: the only code that calls the plugin.
class PurchasesFlutterGateway implements PurchasesGateway {
  PurchasesFlutterGateway._();

  /// Configures the SDK with [apiKey]. Throws if the SDK cannot start.
  static Future<PurchasesFlutterGateway> create(String apiKey) async {
    await rc.Purchases.configure(rc.PurchasesConfiguration(apiKey));
    final gateway = PurchasesFlutterGateway._();
    rc.Purchases.addCustomerInfoUpdateListener(gateway._onCustomerInfo);
    return gateway;
  }

  final StreamController<ServerEntitlement> _updates =
      StreamController<ServerEntitlement>.broadcast();
  final Map<String, rc.Package> _packages = {};

  void _onCustomerInfo(rc.CustomerInfo info) {
    if (!_updates.isClosed) _updates.add(mapCustomerInfo(info));
  }

  @override
  Stream<ServerEntitlement> get updates => _updates.stream;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on Object catch (e) {
      throw mapPurchasesError(e);
    }
  }

  @override
  Future<ServerEntitlement> getEntitlement() =>
      _guard(() async => mapCustomerInfo(await rc.Purchases.getCustomerInfo()));

  @override
  Future<List<PaywallPackage>> getOffering() => _guard(() async {
    final offerings = await rc.Purchases.getOfferings();
    final packages = offerings.current?.availablePackages ?? const [];
    _packages
      ..clear()
      ..addAll({for (final p in packages) p.identifier: p});
    final eligibility = await _eligibility(packages);
    return mapOffering(
      offerings,
      platform: defaultTargetPlatform,
      eligibility: eligibility,
    );
  });

  Future<Map<String, rc.IntroEligibilityStatus>> _eligibility(
    List<rc.Package> packages,
  ) async {
    if (defaultTargetPlatform != TargetPlatform.iOS || packages.isEmpty) {
      return const {};
    }
    try {
      final result =
          await rc.Purchases.checkTrialOrIntroductoryPriceEligibility([
            for (final p in packages) p.storeProduct.identifier,
          ]);
      return {for (final e in result.entries) e.key: e.value.status};
    } on Object catch (e) {
      // Without the answer no trial is promised.
      debugPrint('Intro eligibility check failed: $e');
      return const {};
    }
  }

  @override
  Future<GatewayPurchase> purchase(String packageId) async {
    try {
      var package = _packages[packageId];
      if (package == null) {
        await getOffering();
        package = _packages[packageId];
      }
      if (package == null) {
        throw const PurchaseException(PurchaseFailureKind.store, 'no package');
      }
      final result = await rc.Purchases.purchase(
        rc.PurchaseParams.package(package),
      );
      return GatewayPurchase(
        GatewayPurchaseStatus.purchased,
        mapCustomerInfo(result.customerInfo),
      );
    } on PlatformException catch (e) {
      switch (rc.PurchasesErrorHelper.getErrorCode(e)) {
        case rc.PurchasesErrorCode.purchaseCancelledError:
          return const GatewayPurchase(GatewayPurchaseStatus.cancelled);
        case rc.PurchasesErrorCode.paymentPendingError:
          return const GatewayPurchase(GatewayPurchaseStatus.pending);
        case rc.PurchasesErrorCode.productAlreadyPurchasedError:
          return const GatewayPurchase(GatewayPurchaseStatus.alreadyOwned);
        default:
          throw mapPurchasesError(e);
      }
    } on Object catch (e) {
      throw mapPurchasesError(e);
    }
  }

  @override
  Future<ServerEntitlement> restore() => _guard(
    () async => mapCustomerInfo(await rc.Purchases.restorePurchases()),
  );

  @override
  void dispose() {
    rc.Purchases.removeCustomerInfoUpdateListener(_onCustomerInfo);
    _updates.close();
  }
}
