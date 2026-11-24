import 'package:flutter/foundation.dart';

/// Id of the RevenueCat entitlement that unlocks Premium.
const String premiumEntitlementId = 'premium';

/// RevenueCat public SDK keys. They are never kept in the repository: they come
/// from `--dart-define` at build time (see the README). Without a key the app
/// runs with purchases switched off.
const String _androidKey = String.fromEnvironment('RC_API_KEY_ANDROID');
const String _iosKey = String.fromEnvironment('RC_API_KEY_IOS');

/// The key for [platform]; empty when the build has none.
String revenueCatKeyFor(
  TargetPlatform platform, {
  String androidKey = _androidKey,
  String iosKey = _iosKey,
}) => switch (platform) {
  TargetPlatform.android => androidKey,
  TargetPlatform.iOS => iosKey,
  _ => '',
};

/// Key of the running platform (empty on web and desktop).
String currentRevenueCatKey() =>
    kIsWeb ? '' : revenueCatKeyFor(defaultTargetPlatform);
