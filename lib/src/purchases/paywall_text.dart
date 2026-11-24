import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';

/// Text of the paywall built from the store data of a package. Nothing here
/// invents a price, a period or a trial: every figure is the store's.

/// Message for a failed purchase operation.
String purchaseFailureText(AppLocalizations l, PurchaseFailureKind kind) =>
    switch (kind) {
      PurchaseFailureKind.network => l.paywallErrorNetwork,
      PurchaseFailureKind.store => l.paywallErrorStore,
      PurchaseFailureKind.notActivated => l.paywallNotActivated,
      PurchaseFailureKind.unavailable => l.paywallUnavailable,
      PurchaseFailureKind.unknown => l.paywallErrorUnknown,
    };

/// "3 months", "7 days": a length of time.
String durationText(AppLocalizations l, BillingPeriod p) => switch (p.unit) {
  BillingUnit.day => l.paywallDurationDay(p.count),
  BillingUnit.week => l.paywallDurationWeek(p.count),
  BillingUnit.month => l.paywallDurationMonth(p.count),
  BillingUnit.year => l.paywallDurationYear(p.count),
};

/// What follows the slash in a price: "month" for one unit, "3 months" else.
String perPeriodText(AppLocalizations l, BillingPeriod p) {
  if (p.count != 1) return durationText(l, p);
  return switch (p.unit) {
    BillingUnit.day => l.paywallPerDay,
    BillingUnit.week => l.paywallPerWeek,
    BillingUnit.month => l.paywallPerMonth,
    BillingUnit.year => l.paywallPerYear,
  };
}

/// "PLN 99,99 / 3 months" for a subscription, the plain price when the store
/// gave no period.
String subscriptionPriceText(AppLocalizations l, PaywallPackage p) {
  final period = p.period;
  return period == null
      ? p.priceString
      : l.paywallPricePer(p.priceString, perPeriodText(l, period));
}

/// Name of the plan.
String planName(AppLocalizations l, PaywallPackage p) {
  if (!p.isSubscription) {
    return p.kind == PackageKind.lifetime
        ? l.paywallPlanLifetime
        : (p.title ?? l.paywallPlanLifetime);
  }
  final period = p.period;
  return period != null ? durationText(l, period) : (p.title ?? p.id);
}

/// Price line of the plan.
String planPriceText(AppLocalizations l, PaywallPackage p) => p.isSubscription
    ? subscriptionPriceText(l, p)
    : l.paywallLifetimePrice(p.priceString);

/// The introductory offer line, or null when the store has none for the user.
String? introText(AppLocalizations l, PaywallPackage p) {
  final intro = p.introOffer;
  if (intro == null || !p.isSubscription) return null;
  final then = subscriptionPriceText(l, p);
  final length = durationText(l, intro.period);
  return intro.isFree
      ? l.paywallIntroFree(length, then)
      : l.paywallIntroPaid(length, intro.priceString!, then);
}

/// Auto-renewal and cancellation terms for the store of [platform]: only the
/// App Store on iOS, only Google Play on Android, neutral elsewhere.
String renewalNoticeText(AppLocalizations l, TargetPlatform platform) =>
    switch (platform) {
      TargetPlatform.iOS => l.paywallRenewalNoticeIos,
      TargetPlatform.android => l.paywallRenewalNoticeAndroid,
      _ => l.paywallRenewalNotice,
    };

/// Where to cancel a subscription, for the store of [platform].
String manageSubscriptionText(AppLocalizations l, TargetPlatform platform) =>
    switch (platform) {
      TargetPlatform.iOS => l.paywallSettingsManageIos,
      TargetPlatform.android => l.paywallSettingsManageAndroid,
      _ => l.paywallSettingsManage,
    };
