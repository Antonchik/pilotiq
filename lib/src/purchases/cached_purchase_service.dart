import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:pilotiq/src/purchases/entitlement_cache.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';

/// Holds the entitlement of a [PurchaseService]: the current state, its stream,
/// the persisted cache and the check of the cached period against the clock.
///
/// The server decides. [applyServer] publishes what the backend reported and
/// stores it. Only when the backend cannot be asked (offline, error) the
/// cached state is evaluated by [evaluateCachedEntitlement], which also
/// guards against a device clock that was turned back.
abstract class CachedPurchaseService
    with WidgetsBindingObserver
    implements PurchaseService {
  CachedPurchaseService({this._cache, Clock? clock})
    : _clock = clock ?? const Clock();

  final EntitlementCache? _cache;
  final Clock _clock;
  final StreamController<EntitlementState> _controller =
      StreamController<EntitlementState>.broadcast();

  EntitlementState _current = EntitlementState.free;
  CachedEntitlement _cached = const CachedEntitlement();
  DateTime? _persistedSeen;
  Timer? _timer;
  bool _disposed = false;
  bool _observing = false;

  /// How often the device time is written to the cache while the app runs.
  static const Duration _seenWriteInterval = Duration(hours: 1);

  /// Shortest wait before an expired period is checked again.
  static const Duration _minRecheck = Duration(minutes: 5);

  @override
  Stream<EntitlementState> get entitlement => _controller.stream;

  @override
  EntitlementState get current => _current;

  /// Whether the one-time synchronisation has already succeeded.
  @protected
  bool get syncedOnceDone => _cached.syncedOnce;

  @protected
  DateTime get now => _clock.now();

  /// Reads the cache and publishes the state it allows.
  @protected
  Future<void> loadCache() async {
    final cache = _cache;
    if (cache == null) return;
    try {
      _cached = await cache.read();
      _persistedSeen = _cached.lastSeenAt;
    } on Object catch (e) {
      debugPrint('Reading the purchase cache failed: $e');
      return;
    }
    reevaluate();
  }

  /// Publishes the cached state evaluated at the current moment.
  @protected
  void reevaluate() {
    _bumpSeen();
    _publish(evaluateCachedEntitlement(_cached, _clock.now()));
  }

  int _applied = 0;

  /// Number of backend answers applied so far. An answer that was requested
  /// before another one was applied is stale and must be dropped.
  @protected
  int get appliedCount => _applied;

  /// Takes over the state the backend reported and stores it. [serverTime] is
  /// the time of the backend's answer: it becomes the new `lastSeenAt` even if
  /// that is earlier than the old one (a clock that once ran ahead is fixed
  /// by the next online answer).
  @protected
  void applyServer(EntitlementState state, {DateTime? serverTime}) {
    _applied++;
    final seen = serverTime ?? _bumpSeen();
    if (serverTime != null) {
      _cached = CachedEntitlement(
        isPremium: _cached.isPremium,
        expiresAt: _cached.expiresAt,
        lastSeenAt: serverTime,
        syncedOnce: _cached.syncedOnce,
      );
    }
    _cached = CachedEntitlement(
      isPremium: state.isPremium,
      expiresAt: state.isPremium ? state.expiresAt : null,
      lastSeenAt: seen,
      syncedOnce: _cached.syncedOnce,
    );
    _persistedSeen = seen;
    _publish(state);
    _guarded(() => _cache?.writeEntitlement(state, seen));
  }

  @protected
  Future<void> markSyncedOnce() async {
    _cached = CachedEntitlement(
      isPremium: _cached.isPremium,
      expiresAt: _cached.expiresAt,
      lastSeenAt: _cached.lastSeenAt,
      syncedOnce: true,
    );
    try {
      await _cache?.markSyncedOnce();
    } on Object catch (e) {
      debugPrint('Saving the purchase sync flag failed: $e');
    }
  }

  /// Called when a cached period has run out: ask the backend again. The base
  /// class has none, so it re-evaluates the cache.
  @protected
  Future<void> onPeriodEnded() async => reevaluate();

  /// Largest "now" seen since the last backend answer; written to the cache
  /// about once an hour.
  DateTime _bumpSeen() {
    final t = _clock.now();
    final previous = _cached.lastSeenAt;
    final seen = previous != null && previous.isAfter(t) ? previous : t;
    _cached = CachedEntitlement(
      isPremium: _cached.isPremium,
      expiresAt: _cached.expiresAt,
      lastSeenAt: seen,
      syncedOnce: _cached.syncedOnce,
    );
    final written = _persistedSeen;
    if (written == null || seen.difference(written) >= _seenWriteInterval) {
      _persistedSeen = seen;
      _guarded(() => _cache?.writeLastSeen(seen));
    }
    return seen;
  }

  void _guarded(Future<void>? Function() write) {
    if (_cache == null) return;
    Future<void>.sync(() => write()).catchError((Object e) {
      debugPrint('Saving the purchase cache failed: $e');
    });
  }

  void _publish(EntitlementState state) {
    _scheduleExpiry(state);
    if (state == _current) return;
    _current = state;
    if (!_controller.isClosed) _controller.add(state);
  }

  void _scheduleExpiry(EntitlementState state) {
    _timer?.cancel();
    _timer = null;
    final end = state.expiresAt;
    if (_disposed || !state.isPremium || end == null) return;
    var wait = end.difference(_clock.now());
    if (wait < _minRecheck) wait = _minRecheck;
    _timer = Timer(wait, () {
      _timer = null;
      onPeriodEnded().catchError((Object e) {
        debugPrint('Checking the purchase period failed: $e');
      });
    });
  }

  /// Re-checks the entitlement every time the app comes back to the front.
  @protected
  void observeLifecycle() {
    if (_observing || _disposed) return;
    _observing = true;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refresh().catchError((Object e) {
        debugPrint('Refreshing the entitlement failed: $e');
      });
    }
  }

  @override
  @mustCallSuper
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    _controller.close();
  }
}
