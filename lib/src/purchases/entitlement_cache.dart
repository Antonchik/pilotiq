import 'package:hive_ce/hive.dart';
import 'package:pilotiq/src/progress/stored_time.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';

/// What the cache holds.
class CachedEntitlement {
  const CachedEntitlement({
    this.isPremium = false,
    this.expiresAt,
    this.lastSeenAt,
  });

  final bool isPremium;

  /// End of the paid period; null for lifetime (never expires by itself).
  final DateTime? expiresAt;

  /// The latest moment the app knew to be "now": the server time of the last
  /// successful answer or the largest device time seen since. It is the
  /// protection against a device clock that is turned back (see
  /// [evaluateCachedEntitlement]).
  final DateTime? lastSeenAt;
}

/// Entitlement the app may assume without asking the server (offline, server
/// error): the cached premium counts until [CachedEntitlement.expiresAt], a
/// lifetime one without end.
///
/// The device clock is not trusted to go backwards: the time used is
/// `max(now, lastSeenAt)`, so turning the clock back does not revive an
/// expired period. What remains: someone who stays offline and rolls the
/// clock back before the period ends gets at most the rolled-back time extra,
/// and the first answer from the server (which decides, and which also resets
/// `lastSeenAt` to the server time) ends it.
EntitlementState evaluateCachedEntitlement(
  CachedEntitlement cached,
  DateTime now,
) {
  if (!cached.isPremium) return EntitlementState.free;
  final seen = cached.lastSeenAt;
  final effective = seen != null && seen.isAfter(now) ? seen : now;
  final end = cached.expiresAt;
  if (end != null && !effective.isBefore(end)) return EntitlementState.free;
  return EntitlementState(isPremium: true, expiresAt: end);
}

/// Last known entitlement, stored in the `config` box.
/// Moments are UTC strings (see `stored_time.dart`). A failing box never
/// throws into the app: callers log and carry on with what they have in
/// memory.
///
/// The default opener never lets Hive repair a damaged file: that is done by
/// the progress repository, which first keeps a backup copy. If the box cannot
/// be opened here, the cache stays empty and is tried again at the next use.
class EntitlementCache {
  EntitlementCache({Future<Box<dynamic>> Function()? openBox})
    : _open =
          openBox ??
          (() => Hive.openBox<dynamic>('config', crashRecovery: false));

  static const String premiumKey = 'rcPremium';
  static const String expiresAtKey = 'rcExpiresAt';
  static const String lastSeenKey = 'rcLastSeenAt';

  final Future<Box<dynamic>> Function() _open;
  Future<Box<dynamic>>? _box;

  Future<Box<dynamic>> _config() {
    final existing = _box;
    if (existing != null) return existing;
    final opening = _open();
    _box = opening;
    opening.then<void>((_) {}, onError: (Object _) => _box = null);
    return opening;
  }

  Future<CachedEntitlement> read() async {
    final box = await _config();
    return CachedEntitlement(
      isPremium: box.get(premiumKey) == true,
      expiresAt: decodeMoment(box.get(expiresAtKey)),
      lastSeenAt: decodeMoment(box.get(lastSeenKey)),
    );
  }

  /// Stores the entitlement the server reported and the moment it was true.
  Future<void> writeEntitlement(EntitlementState state, DateTime seenAt) async {
    final box = await _config();
    await box.putAll({
      premiumKey: state.isPremium,
      expiresAtKey: state.isPremium && state.expiresAt != null
          ? encodeMoment(state.expiresAt!)
          : null,
      lastSeenKey: encodeMoment(seenAt),
    });
  }

  Future<void> writeLastSeen(DateTime seenAt) async {
    final box = await _config();
    await box.put(lastSeenKey, encodeMoment(seenAt));
  }
}
