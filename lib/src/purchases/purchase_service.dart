import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/purchases/disabled_purchase_service.dart';

/// Kind of a purchasable package shown on the paywall.
enum PackageKind { lifetime, monthly, quarterly, other }

/// Unit of a billing period or of an introductory offer.
enum BillingUnit { day, week, month, year }

/// A length of time as the store reports it (for example 3 months).
class BillingPeriod {
  const BillingPeriod(this.unit, this.count);

  final BillingUnit unit;
  final int count;

  /// Parses an ISO 8601 period such as `P3M`, `P1W`, `P7D` or `P1Y`. Returns
  /// null for anything else (mixed periods such as `P1Y6M` included), so the
  /// paywall shows nothing rather than a wrong period.
  static BillingPeriod? tryParseIso(String? iso) {
    if (iso == null) return null;
    final m = RegExp(r'^P(\d+)([DWMY])$').firstMatch(iso.trim());
    if (m == null) return null;
    final count = int.parse(m.group(1)!);
    if (count <= 0) return null;
    return BillingPeriod(switch (m.group(2)) {
      'D' => BillingUnit.day,
      'W' => BillingUnit.week,
      'M' => BillingUnit.month,
      _ => BillingUnit.year,
    }, count);
  }

  @override
  bool operator ==(Object other) =>
      other is BillingPeriod && other.unit == unit && other.count == count;

  @override
  int get hashCode => Object.hash(unit, count);

  @override
  String toString() => 'BillingPeriod($count $unit)';
}

/// An introductory offer of a subscription as the store reports it: a free
/// trial ([priceString] is null) or a reduced first period.
class IntroOffer {
  const IntroOffer({required this.period, this.priceString});

  final BillingPeriod period;

  /// Price of the introductory period; null for a free trial.
  final String? priceString;

  bool get isFree => priceString == null;
}

/// One purchasable option of the current offering. Prices come from the store
/// already formatted ([priceString]); the app never computes prices itself.
class PaywallPackage {
  const PaywallPackage({
    required this.id,
    required this.kind,
    required this.priceString,
    this.period,
    this.introOffer,
    this.title,
    this._isSubscription,
  });

  final String id;
  final PackageKind kind;
  final String priceString;

  /// Billing period of a subscription as reported by the store; for a prepaid
  /// plan (not a subscription) the length of the access it pays for.
  final BillingPeriod? period;

  /// Introductory offer the user can actually get, if any. Null means that
  /// the paywall says nothing about a trial.
  final IntroOffer? introOffer;

  /// Product title from the store; shown when the plan cannot be named from
  /// [period].
  final String? title;

  final bool? _isSubscription;

  /// A subscription renews automatically; anything else is a one-time payment.
  bool get isSubscription => _isSubscription ?? kind != PackageKind.lifetime;

  /// A one-time payment for access of a limited [period] (Google Play
  /// prepaid plan): neither a subscription nor lifetime.
  bool get isPrepaid => !isSubscription && period != null;
}

/// Premium entitlement as last known by the purchase service.
class EntitlementState {
  const EntitlementState({required this.isPremium, this.expiresAt});

  static const free = EntitlementState(isPremium: false);

  final bool isPremium;

  /// End of the current period; `null` for lifetime or when not premium.
  final DateTime? expiresAt;

  @override
  bool operator ==(Object other) =>
      other is EntitlementState &&
      other.isPremium == isPremium &&
      other.expiresAt == expiresAt;

  @override
  int get hashCode => Object.hash(isPremium, expiresAt);

  @override
  String toString() => 'EntitlementState($isPremium, $expiresAt)';
}

/// Result of [PurchaseService.purchase] that is not an error.
enum PurchaseOutcome {
  /// The purchase went through and Premium is active.
  purchased,

  /// The user closed the store sheet. Not an error.
  cancelled,

  /// The payment waits for approval (Ask to Buy, delayed payment). Premium is
  /// not granted until the store confirms it.
  pending,
}

/// Why a purchase operation failed; the paywall picks the message from it.
enum PurchaseFailureKind {
  /// No connection or the server could not be reached.
  network,

  /// The store reported a problem (store unavailable, product not available).
  store,

  /// The payment went through but the entitlement is not active.
  notActivated,

  /// Purchases are not available in this build.
  unavailable,

  unknown,
}

class PurchaseException implements Exception {
  const PurchaseException(this.kind, [this.detail]);

  final PurchaseFailureKind kind;
  final String? detail;

  @override
  String toString() =>
      'PurchaseException($kind${detail == null ? '' : ': $detail'})';
}

/// Plans in the order the paywall shows them: lifetime first, then 3 months,
/// 1 month and the rest in the order of the store.
List<PaywallPackage> sortedForPaywall(List<PaywallPackage> packages) {
  int rank(PaywallPackage p) => switch (p.kind) {
    PackageKind.lifetime => 0,
    PackageKind.quarterly => 1,
    PackageKind.monthly => 2,
    PackageKind.other => 3,
  };
  final indexed = packages.indexed.toList()
    ..sort((a, b) {
      final byRank = rank(a.$2).compareTo(rank(b.$2));
      return byRank != 0 ? byRank : a.$1.compareTo(b.$1);
    });
  return [for (final e in indexed) e.$2];
}

/// Abstraction over the store/billing backend. Tests use
/// `FakePurchaseService`; the app uses `RevenueCatPurchaseService`, or
/// `DisabledPurchaseService` in a build without keys.
abstract class PurchaseService {
  /// False in a build without store keys: nothing can be bought or restored.
  bool get isAvailable;

  /// Emits every change of the entitlement.
  Stream<EntitlementState> get entitlement;

  /// Last known entitlement (available synchronously).
  EntitlementState get current;

  /// Asks the backend for the entitlement. Never throws: on a failure the last
  /// known state (the cache) stays.
  Future<void> refresh();

  /// Plans to show, in the order of the store. Throws [PurchaseException] on a
  /// failure; an empty list means that the store has nothing to offer.
  Future<List<PaywallPackage>> getOffering();

  /// Buys the package with [packageId]. Cancelling and a pending payment are
  /// outcomes, not errors; real errors throw [PurchaseException].
  Future<PurchaseOutcome> purchase(String packageId);

  /// Restores purchases and returns the resulting entitlement. Throws
  /// [PurchaseException] on a failure.
  Future<EntitlementState> restore();

  /// Releases streams, timers and listeners.
  void dispose();
}

/// The service of the app. `initializeApp` overrides it with the real one; the
/// default is a build without store keys (nothing to buy, always free).
final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  final service = DisabledPurchaseService();
  ref.onDispose(service.dispose);
  return service;
});

final entitlementProvider = StreamProvider<EntitlementState>((ref) async* {
  final service = ref.watch(purchaseServiceProvider);
  yield service.current;
  yield* service.entitlement;
});

/// The only place premium gating should read from.
final isPremiumProvider = Provider<bool>((ref) {
  final service = ref.watch(purchaseServiceProvider);
  final state = ref.watch(entitlementProvider);
  return (state.value ?? service.current).isPremium;
});
