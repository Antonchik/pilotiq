import 'package:pilotiq/src/purchases/cached_purchase_service.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';

/// Service of a build without store keys. Nothing can be bought or restored;
/// the app works, the paywall says so. Premium that was cached earlier (for
/// example by a build that had the keys) is honoured until its end.
class DisabledPurchaseService extends CachedPurchaseService {
  DisabledPurchaseService({super.cache, super.clock});

  /// Reads the cache; call once after creating the service.
  Future<void> start() => loadCache();

  @override
  bool get isAvailable => false;

  @override
  Future<void> refresh() async => reevaluate();

  @override
  Future<List<PaywallPackage>> getOffering() =>
      Future.error(const PurchaseException(PurchaseFailureKind.unavailable));

  @override
  Future<PurchaseOutcome> purchase(String packageId) =>
      Future.error(const PurchaseException(PurchaseFailureKind.unavailable));

  @override
  Future<EntitlementState> restore() =>
      Future.error(const PurchaseException(PurchaseFailureKind.unavailable));

  @override
  Future<void> syncOnce() async {}
}
