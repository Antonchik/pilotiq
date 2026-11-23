import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/purchases/fake_purchase_service.dart';

/// Kind of a purchasable package shown on the paywall.
enum PackageKind { lifetime, monthly, quarterly, other }

/// One purchasable option of the current offering. Prices come from the store
/// already formatted ([priceString]); the app never computes prices itself.
class PaywallPackage {
  const PaywallPackage({
    required this.id,
    required this.kind,
    required this.priceString,
    this.introOffer,
  });

  final String id;
  final PackageKind kind;
  final String priceString;

  /// Human readable introductory offer (for example a free trial), if any.
  final String? introOffer;
}

/// Premium entitlement as last known by the purchase service.
class EntitlementState {
  const EntitlementState({required this.isPremium, this.expiresAt});

  static const free = EntitlementState(isPremium: false);

  final bool isPremium;

  /// End of the current period; `null` for lifetime or when not premium.
  final DateTime? expiresAt;
}

/// Abstraction over the store/billing backend. The only implementation in
/// tests is [FakePurchaseService]; a real one is provided by the paywall step.
abstract class PurchaseService {
  /// Emits every change of the entitlement.
  Stream<EntitlementState> get entitlement;

  /// Last known entitlement (available synchronously).
  EntitlementState get current;

  Future<void> refresh();

  Future<List<PaywallPackage>> getOffering();

  /// Buys the package with [packageId]. Completes normally when the user
  /// cancels; throws on real errors.
  Future<void> purchase(String packageId);

  Future<void> restore();

  /// One-time silent synchronisation of purchases made before the update.
  Future<void> syncOnce();
}

/// Default service until the real billing backend is wired in: always free.
final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  final service = FakePurchaseService();
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
