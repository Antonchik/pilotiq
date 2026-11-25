import 'dart:async';

import 'package:pilotiq/src/purchases/purchase_service.dart';
import 'package:pilotiq/src/purchases/purchases_gateway.dart';

/// Scriptable store backend for the service tests.
class FakeGateway implements PurchasesGateway {
  final StreamController<ServerEntitlement> _updates =
      StreamController<ServerEntitlement>.broadcast();

  /// What the backend reports.
  ServerEntitlement entitlement = const ServerEntitlement(isActive: false);

  /// Thrown by every call while set (the network is down).
  PurchaseException? failure;

  /// While set, [getEntitlement] waits for it (a slow answer).
  Completer<void>? entitlementGate;

  List<PaywallPackage> offering = const [];
  GatewayPurchase purchaseResult = const GatewayPurchase(
    GatewayPurchaseStatus.cancelled,
  );

  int getEntitlementCalls = 0;
  int restoreCalls = 0;
  final List<String> purchases = [];
  bool disposed = false;

  void push(ServerEntitlement e) => _updates.add(e);

  void _check() {
    final f = failure;
    if (f != null) throw f;
  }

  @override
  Stream<ServerEntitlement> get updates => _updates.stream;

  @override
  Future<ServerEntitlement> getEntitlement() async {
    getEntitlementCalls++;
    final answer = entitlement;
    await entitlementGate?.future;
    _check();
    return answer;
  }

  @override
  Future<List<PaywallPackage>> getOffering() async {
    _check();
    return offering;
  }

  @override
  Future<GatewayPurchase> purchase(String packageId) async {
    purchases.add(packageId);
    _check();
    return purchaseResult;
  }

  @override
  Future<ServerEntitlement> restore() async {
    restoreCalls++;
    _check();
    return entitlement;
  }

  @override
  void dispose() {
    disposed = true;
    _updates.close();
  }
}
