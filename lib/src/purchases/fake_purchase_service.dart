import 'dart:async';

import 'package:pilotiq/src/purchases/purchase_service.dart';

/// In-memory [PurchaseService] for tests, with switches for the scenarios of
/// the paywall: pending and cancelled payments, errors, a lost entitlement,
/// an empty offering, an introductory offer.
class FakePurchaseService implements PurchaseService {
  FakePurchaseService({
    bool premium = false,
    List<PaywallPackage>? offering,
    this.isAvailable = true,
  }) : _current = EntitlementState(isPremium: premium),
       offering = offering ?? defaultOffering;

  static const defaultOffering = [
    PaywallPackage(
      id: 'lifetime',
      kind: PackageKind.lifetime,
      priceString: '—',
    ),
    PaywallPackage(
      id: 'quarterly',
      kind: PackageKind.quarterly,
      priceString: '—',
      period: BillingPeriod(BillingUnit.month, 3),
    ),
    PaywallPackage(
      id: 'monthly',
      kind: PackageKind.monthly,
      priceString: '—',
      period: BillingPeriod(BillingUnit.month, 1),
    ),
  ];

  /// Prices as a store would report them, with a free trial on the 3 months.
  static const storeLikeOffering = [
    PaywallPackage(
      id: 'monthly',
      kind: PackageKind.monthly,
      priceString: 'PLN 24,99',
      period: BillingPeriod(BillingUnit.month, 1),
    ),
    PaywallPackage(
      id: 'quarterly',
      kind: PackageKind.quarterly,
      priceString: 'PLN 59,99',
      period: BillingPeriod(BillingUnit.month, 3),
      introOffer: IntroOffer(period: BillingPeriod(BillingUnit.day, 3)),
    ),
    PaywallPackage(
      id: 'lifetime',
      kind: PackageKind.lifetime,
      priceString: 'PLN 99,99',
    ),
  ];

  /// The same plans with long prices, for layout tests.
  static const longPriceOffering = [
    PaywallPackage(
      id: 'lifetime',
      kind: PackageKind.lifetime,
      priceString: 'PLN 1 099,99',
    ),
    PaywallPackage(
      id: 'quarterly',
      kind: PackageKind.quarterly,
      priceString: 'PLN 99,99',
      period: BillingPeriod(BillingUnit.month, 3),
      introOffer: IntroOffer(period: BillingPeriod(BillingUnit.day, 3)),
    ),
    PaywallPackage(
      id: 'monthly',
      kind: PackageKind.monthly,
      priceString: 'PLN 39,99',
      period: BillingPeriod(BillingUnit.month, 1),
    ),
  ];

  final StreamController<EntitlementState> _controller =
      StreamController<EntitlementState>.broadcast();
  EntitlementState _current;

  @override
  bool isAvailable;

  /// Packages returned by [getOffering].
  List<PaywallPackage> offering;

  /// Thrown by [getOffering] while set.
  PurchaseException? offeringError;

  /// While set, [getOffering] waits for it (to show the loading state).
  Completer<void>? offeringGate;

  /// What [purchase] reports.
  PurchaseOutcome purchaseOutcome = PurchaseOutcome.purchased;

  /// Thrown by [purchase] while set.
  PurchaseException? purchaseError;

  /// While set, [purchase] waits for it (to show the purchase in progress).
  Completer<void>? purchaseGate;

  /// Thrown by [restore] while set.
  PurchaseException? restoreError;

  /// Whether [restore] finds Premium.
  bool restoreFindsPremium = true;

  /// Ids passed to [purchase], in call order.
  final List<String> purchasedIds = [];
  int refreshCalls = 0;
  int restoreCalls = 0;
  int syncOnceCalls = 0;
  int offeringCalls = 0;
  bool disposed = false;

  @override
  Stream<EntitlementState> get entitlement => _controller.stream;

  @override
  EntitlementState get current => _current;

  /// Test helper: changes the entitlement and notifies listeners.
  void setEntitlement(EntitlementState state) {
    _current = state;
    if (!_controller.isClosed) _controller.add(state);
  }

  /// Test helper: the backend stops reporting Premium (expiry, refund).
  void loseEntitlement() => setEntitlement(EntitlementState.free);

  @override
  Future<void> refresh() async {
    refreshCalls++;
  }

  @override
  Future<List<PaywallPackage>> getOffering() async {
    offeringCalls++;
    await offeringGate?.future;
    final error = offeringError;
    if (error != null) throw error;
    return offering;
  }

  @override
  Future<PurchaseOutcome> purchase(String packageId) async {
    purchasedIds.add(packageId);
    await purchaseGate?.future;
    final error = purchaseError;
    if (error != null) throw error;
    if (purchaseOutcome == PurchaseOutcome.purchased) {
      setEntitlement(const EntitlementState(isPremium: true));
    }
    return purchaseOutcome;
  }

  @override
  Future<EntitlementState> restore() async {
    restoreCalls++;
    final error = restoreError;
    if (error != null) throw error;
    if (restoreFindsPremium) {
      setEntitlement(const EntitlementState(isPremium: true));
    }
    return _current;
  }

  @override
  Future<void> syncOnce() async {
    syncOnceCalls++;
  }

  @override
  void dispose() {
    disposed = true;
    _controller.close();
  }
}
