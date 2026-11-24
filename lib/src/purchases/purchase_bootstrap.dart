import 'package:flutter/foundation.dart';
import 'package:pilotiq/src/purchases/disabled_purchase_service.dart';
import 'package:pilotiq/src/purchases/entitlement_cache.dart';
import 'package:pilotiq/src/purchases/purchase_config.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';
import 'package:pilotiq/src/purchases/purchases_flutter_gateway.dart';
import 'package:pilotiq/src/purchases/purchases_gateway.dart';
import 'package:pilotiq/src/purchases/revenuecat_purchase_service.dart';

/// Creates the purchase service of the app. Never throws and never waits for
/// the network: without a key, or if the store SDK cannot start, the app runs
/// with [DisabledPurchaseService] (cached Premium still counts); otherwise the
/// refresh and the one-time sync of purchases continue in the background.
Future<PurchaseService> createPurchaseService({
  String? apiKey,
  EntitlementCache? cache,
  Future<PurchasesGateway> Function(String apiKey) createGateway =
      PurchasesFlutterGateway.create,
}) async {
  final store = cache ?? EntitlementCache();
  final key = apiKey ?? currentRevenueCatKey();
  if (key.isNotEmpty) {
    try {
      final service = RevenueCatPurchaseService(
        gateway: await createGateway(key),
        cache: store,
      );
      await service.start();
      return service;
    } on Object catch (e) {
      debugPrint('Purchases are switched off, the store SDK failed: $e');
    }
  }
  final disabled = DisabledPurchaseService(cache: store);
  await disabled.start();
  return disabled;
}
