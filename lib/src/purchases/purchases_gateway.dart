import 'package:pilotiq/src/purchases/purchase_service.dart';

/// What the backend says about the Premium entitlement.
class ServerEntitlement {
  const ServerEntitlement({required this.isActive, this.expiresAt});

  final bool isActive;

  /// End of the paid period; null for a lifetime purchase.
  final DateTime? expiresAt;

  EntitlementState toState() => isActive
      ? EntitlementState(isPremium: true, expiresAt: expiresAt)
      : EntitlementState.free;
}

enum GatewayPurchaseStatus { purchased, cancelled, pending, alreadyOwned }

class GatewayPurchase {
  const GatewayPurchase(this.status, [this.entitlement]);

  final GatewayPurchaseStatus status;
  final ServerEntitlement? entitlement;
}

/// The part of the store SDK the service needs, in the app's own types. The
/// only implementation that talks to the plugin is `PurchasesFlutterGateway`;
/// tests use a fake. Methods throw `PurchaseException` on failures.
abstract class PurchasesGateway {
  /// Entitlement changes pushed by the SDK (a renewal, a purchase made
  /// elsewhere, a refund).
  Stream<ServerEntitlement> get updates;

  Future<ServerEntitlement> getEntitlement();

  Future<List<PaywallPackage>> getOffering();

  Future<GatewayPurchase> purchase(String packageId);

  Future<ServerEntitlement> restore();

  /// `syncPurchases`: sends the purchases of the store account to the backend.
  Future<ServerEntitlement> sync();

  void dispose();
}
