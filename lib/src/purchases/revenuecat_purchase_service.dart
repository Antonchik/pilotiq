import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pilotiq/src/purchases/cached_purchase_service.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';
import 'package:pilotiq/src/purchases/purchases_gateway.dart';

/// [PurchaseService] over the store backend (RevenueCat), with the cache for
/// offline use. The entitlement `premium` of the backend is the source of
/// truth; the cache only stands in while the backend cannot be reached.
class RevenueCatPurchaseService extends CachedPurchaseService {
  RevenueCatPurchaseService({required this._gateway, super.cache, super.clock});

  final PurchasesGateway _gateway;
  StreamSubscription<ServerEntitlement>? _updates;
  Future<void>? _warmUp;

  /// Reads the cache, starts listening for backend updates and, in the
  /// background, refreshes the entitlement and runs the one-time sync. Does not
  /// wait for the network: the app starts with what the cache allows.
  Future<void> start() async {
    await loadCache();
    _updates = _gateway.updates.listen(
      (e) => applyServer(e.toState()),
      onError: (Object e) => debugPrint('Entitlement update failed: $e'),
    );
    observeLifecycle();
    _warmUp = _backgroundStart();
    _warmUp!.ignore();
  }

  /// Completes when the background refresh and sync of [start] are done.
  @visibleForTesting
  Future<void> get backgroundStart => _warmUp ?? Future<void>.value();

  Future<void> _backgroundStart() async {
    await syncOnce();
    await refresh();
  }

  @override
  bool get isAvailable => true;

  @override
  Future<void> refresh() async {
    try {
      applyServer((await _gateway.getEntitlement()).toState());
    } on Object catch (e) {
      debugPrint('Entitlement refresh failed, using the cache: $e');
      reevaluate();
    }
  }

  @override
  Future<void> onPeriodEnded() => refresh();

  @override
  Future<List<PaywallPackage>> getOffering() => _gateway.getOffering();

  @override
  Future<PurchaseOutcome> purchase(String packageId) async {
    final result = await _gateway.purchase(packageId);
    switch (result.status) {
      case GatewayPurchaseStatus.cancelled:
        return PurchaseOutcome.cancelled;
      case GatewayPurchaseStatus.pending:
        return PurchaseOutcome.pending;
      case GatewayPurchaseStatus.alreadyOwned:
        // The store account already owns it: same as a restore.
        final restored = await restore();
        if (!restored.isPremium) {
          throw const PurchaseException(PurchaseFailureKind.notActivated);
        }
        return PurchaseOutcome.purchased;
      case GatewayPurchaseStatus.purchased:
        final entitlement = result.entitlement;
        if (entitlement == null || !entitlement.isActive) {
          // The store took the payment but the backend does not show Premium:
          // do not unlock, point the user to "Restore purchases".
          if (entitlement != null) applyServer(entitlement.toState());
          throw const PurchaseException(PurchaseFailureKind.notActivated);
        }
        applyServer(entitlement.toState());
        return PurchaseOutcome.purchased;
    }
  }

  @override
  Future<EntitlementState> restore() async {
    final state = (await _gateway.restore()).toState();
    applyServer(state);
    return state;
  }

  @override
  Future<void> syncOnce() async {
    if (syncedOnceDone) return;
    try {
      applyServer((await _gateway.sync()).toState());
      await markSyncedOnce();
    } on Object catch (e) {
      // Not marked: the next start tries again.
      debugPrint('One-time purchase sync failed, will retry next start: $e');
    }
  }

  @override
  void dispose() {
    _updates?.cancel();
    _gateway.dispose();
    super.dispose();
  }
}
