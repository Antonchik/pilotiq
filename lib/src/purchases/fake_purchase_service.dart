import 'dart:async';

import 'package:pilotiq/src/purchases/purchase_service.dart';

/// In-memory [PurchaseService] for tests and for builds without billing.
class FakePurchaseService implements PurchaseService {
  FakePurchaseService({
    bool premium = false,
    List<PaywallPackage>? offering,
  })  : _current = EntitlementState(isPremium: premium),
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
    ),
    PaywallPackage(
      id: 'monthly',
      kind: PackageKind.monthly,
      priceString: '—',
    ),
  ];

  final StreamController<EntitlementState> _controller =
      StreamController<EntitlementState>.broadcast();
  EntitlementState _current;

  /// Packages returned by [getOffering].
  List<PaywallPackage> offering;

  /// Ids passed to [purchase], in call order.
  final List<String> purchasedIds = [];
  int refreshCalls = 0;
  int restoreCalls = 0;
  int syncOnceCalls = 0;

  @override
  Stream<EntitlementState> get entitlement => _controller.stream;

  @override
  EntitlementState get current => _current;

  /// Test helper: changes the entitlement and notifies listeners.
  void setEntitlement(EntitlementState state) {
    _current = state;
    if (!_controller.isClosed) _controller.add(state);
  }

  @override
  Future<void> refresh() async {
    refreshCalls++;
  }

  @override
  Future<List<PaywallPackage>> getOffering() async => offering;

  @override
  Future<void> purchase(String packageId) async {
    purchasedIds.add(packageId);
    setEntitlement(const EntitlementState(isPremium: true));
  }

  @override
  Future<void> restore() async {
    restoreCalls++;
  }

  @override
  Future<void> syncOnce() async {
    syncOnceCalls++;
  }

  void dispose() {
    _controller.close();
  }
}
