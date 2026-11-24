import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pilotiq/src/purchases/entitlement_cache.dart';
import 'package:pilotiq/src/purchases/purchase_bootstrap.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';
import 'package:pilotiq/src/purchases/purchases_gateway.dart';
import 'package:pilotiq/src/purchases/revenuecat_purchase_service.dart';

import '../bank/memory_hive.dart';
import 'fake_gateway.dart';

const _premium = ServerEntitlement(isActive: true);
const _free = ServerEntitlement(isActive: false);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeGateway gateway;
  late EntitlementCache cache;
  late DateTime now;
  late List<RevenueCatPurchaseService> services;

  setUp(() async {
    await openMemoryBox('config');
    gateway = FakeGateway();
    cache = EntitlementCache();
    now = DateTime.utc(2026, 11, 24, 12);
    services = [];
  });

  tearDown(() async {
    for (final s in services) {
      s.dispose();
    }
    await Hive.close();
  });

  /// A new "launch of the app": a service over the shared cache box.
  Future<RevenueCatPurchaseService> launch({FakeGateway? using}) async {
    final service = RevenueCatPurchaseService(
      gateway: using ?? gateway,
      cache: cache,
      clock: Clock(() => now),
    );
    services.add(service);
    await service.start();
    await service.backgroundStart;
    return service;
  }

  ServerEntitlement until(DateTime end) =>
      ServerEntitlement(isActive: true, expiresAt: end);

  group('source of truth and cache', () {
    test(
      'the backend entitlement makes the user premium and is cached',
      () async {
        gateway.entitlement = _premium;
        final service = await launch();
        expect(service.current.isPremium, isTrue);

        // A later launch without a network still sees Premium (lifetime).
        gateway.failure = const PurchaseException(PurchaseFailureKind.network);
        final offline = await launch();
        expect(offline.current.isPremium, isTrue);
      },
    );

    test(
      'a network error with a cached period in the future keeps Premium',
      () async {
        gateway.entitlement = until(now.add(const Duration(days: 10)));
        await launch();

        gateway.failure = const PurchaseException(PurchaseFailureKind.network);
        final offline = await launch();
        expect(offline.current.isPremium, isTrue);
      },
    );

    test('a network error with an expired cached period gives free', () async {
      gateway.entitlement = until(now.add(const Duration(days: 10)));
      await launch();

      now = now.add(const Duration(days: 11));
      gateway.failure = const PurchaseException(PurchaseFailureKind.network);
      final offline = await launch();
      expect(offline.current.isPremium, isFalse);
    });

    test(
      'the backend saying "not active" removes Premium, also mid-session',
      () async {
        gateway.entitlement = _premium;
        final service = await launch();
        final seen = <bool>[];
        service.entitlement.listen((e) => seen.add(e.isPremium));

        gateway.entitlement = _free;
        gateway.push(
          _free,
        ); // refund, expiry or cancellation reported by the SDK
        await pumpEventQueue();
        expect(service.current.isPremium, isFalse);
        expect(seen, [false]);

        // The cache follows: the next launch offline stays free.
        gateway.failure = const PurchaseException(PurchaseFailureKind.network);
        final offline = await launch();
        expect(offline.current.isPremium, isFalse);
      },
    );

    test(
      'a refresh that says "not active" overrides a cached premium',
      () async {
        gateway.entitlement = _premium;
        final service = await launch();
        gateway.entitlement = _free;
        await service.refresh();
        expect(service.current.isPremium, isFalse);
      },
    );

    test('the SDK may report a renewal with a new end date', () async {
      gateway.entitlement = until(now.add(const Duration(days: 1)));
      final service = await launch();
      final end = now.add(const Duration(days: 31));
      gateway.push(until(end));
      await pumpEventQueue();
      expect(service.current.expiresAt, end);
    });

    test('a refresh that fails keeps what is known', () async {
      gateway.entitlement = _premium;
      final service = await launch();
      gateway.failure = const PurchaseException(PurchaseFailureKind.network);
      await service.refresh();
      expect(service.current.isPremium, isTrue);
    });

    test('an ended period is asked again at the backend', () async {
      gateway.entitlement = until(now.add(const Duration(days: 1)));
      final service = await launch();
      final calls = gateway.getEntitlementCalls;
      // What the timer does when the period ends.
      await service.onPeriodEnded();
      expect(gateway.getEntitlementCalls, calls + 1);
    });
  });

  group('device clock', () {
    test('turning the clock back does not revive an expired period', () async {
      final end = now.add(const Duration(days: 10));
      gateway.entitlement = until(end);
      await launch();

      // The app runs after the end: the cache says free and remembers the time.
      now = end.add(const Duration(days: 1));
      gateway.failure = const PurchaseException(PurchaseFailureKind.network);
      final expired = await launch();
      expect(expired.current.isPremium, isFalse);
      // That moment is stored (the cache write happens in the background).
      await pumpEventQueue();

      // The user sets the clock back to a day inside the paid period.
      now = end.subtract(const Duration(days: 3));
      final tampered = await launch();
      expect(tampered.current.isPremium, isFalse);
    });

    test(
      'evaluate: lastSeenAt after "now" wins, lifetime ignores the clock',
      () {
        final end = DateTime.utc(2026, 12, 1);
        final cached = CachedEntitlement(
          isPremium: true,
          expiresAt: end,
          lastSeenAt: DateTime.utc(2026, 12, 2),
        );
        expect(
          evaluateCachedEntitlement(
            cached,
            DateTime.utc(2026, 11, 20),
          ).isPremium,
          isFalse,
        );
        expect(
          evaluateCachedEntitlement(
            CachedEntitlement(
              isPremium: true,
              expiresAt: end,
              lastSeenAt: DateTime.utc(2026, 11, 25),
            ),
            DateTime.utc(2026, 11, 20),
          ).isPremium,
          isTrue,
        );
        expect(
          evaluateCachedEntitlement(
            CachedEntitlement(isPremium: true, lastSeenAt: DateTime.utc(2099)),
            DateTime.utc(2026, 11, 20),
          ).isPremium,
          isTrue,
        );
        expect(
          evaluateCachedEntitlement(
            const CachedEntitlement(),
            DateTime.now(),
          ).isPremium,
          isFalse,
        );
      },
    );

    test('moments are stored as UTC strings', () async {
      gateway.entitlement = until(DateTime.utc(2026, 12, 31, 8));
      await launch();
      final box = Hive.box<dynamic>('config');
      expect(
        box.get(EntitlementCache.expiresAtKey),
        '2026-12-31T08:00:00.000Z',
      );
      expect(box.get(EntitlementCache.lastSeenKey), endsWith('Z'));
    });
  });

  group('one-time synchronisation of earlier purchases', () {
    test('syncPurchases runs exactly once over two launches', () async {
      gateway.entitlement = _premium;
      await launch();
      expect(gateway.syncCalls, 1);
      await launch();
      expect(gateway.syncCalls, 1);
    });

    test('a failed sync is repeated at the next launch', () async {
      gateway.failure = const PurchaseException(PurchaseFailureKind.network);
      await launch();
      expect(gateway.syncCalls, 1);

      gateway.failure = null;
      gateway.entitlement = _premium;
      final second = await launch();
      expect(gateway.syncCalls, 2);
      expect(second.current.isPremium, isTrue);

      await launch();
      expect(gateway.syncCalls, 2);
    });

    test(
      'a subscriber of the old version gets Premium without buying',
      () async {
        // The backend does not know the store purchase until the sync.
        gateway.entitlement = _free;
        gateway.entitlementAfterSync = until(now.add(const Duration(days: 20)));
        final service = await launch();
        expect(service.current.isPremium, isTrue);
        expect(gateway.syncCalls, 1);
      },
    );
  });

  group('purchase, restore, offering', () {
    test('a purchase that the backend confirms unlocks Premium', () async {
      final service = await launch();
      gateway.purchaseResult = const GatewayPurchase(
        GatewayPurchaseStatus.purchased,
        _premium,
      );
      expect(await service.purchase('lifetime'), PurchaseOutcome.purchased);
      expect(service.current.isPremium, isTrue);
      expect(gateway.purchases, ['lifetime']);
    });

    test('cancelling is an outcome, not an error', () async {
      final service = await launch();
      gateway.purchaseResult = const GatewayPurchase(
        GatewayPurchaseStatus.cancelled,
      );
      expect(await service.purchase('x'), PurchaseOutcome.cancelled);
      expect(service.current.isPremium, isFalse);
    });

    test('a pending payment grants nothing', () async {
      final service = await launch();
      gateway.purchaseResult = const GatewayPurchase(
        GatewayPurchaseStatus.pending,
      );
      expect(await service.purchase('x'), PurchaseOutcome.pending);
      expect(service.current.isPremium, isFalse);
    });

    test(
      'a payment the backend does not show as Premium is an error',
      () async {
        final service = await launch();
        gateway.purchaseResult = const GatewayPurchase(
          GatewayPurchaseStatus.purchased,
          _free,
        );
        await expectLater(
          service.purchase('x'),
          throwsA(
            isA<PurchaseException>().having(
              (e) => e.kind,
              'kind',
              PurchaseFailureKind.notActivated,
            ),
          ),
        );
        expect(service.current.isPremium, isFalse);
      },
    );

    test('"already purchased" is handled as a restore', () async {
      final service = await launch();
      gateway.purchaseResult = const GatewayPurchase(
        GatewayPurchaseStatus.alreadyOwned,
      );
      gateway.entitlement = _premium;
      expect(await service.purchase('x'), PurchaseOutcome.purchased);
      expect(gateway.restoreCalls, 1);
      expect(service.current.isPremium, isTrue);
    });

    test('a purchase error is thrown to the caller', () async {
      final service = await launch();
      gateway.failure = const PurchaseException(PurchaseFailureKind.network);
      await expectLater(
        service.purchase('x'),
        throwsA(isA<PurchaseException>()),
      );
    });

    test('restore with an active entitlement gives Premium', () async {
      final service = await launch();
      gateway.entitlement = _premium;
      final state = await service.restore();
      expect(state.isPremium, isTrue);
      expect(service.current.isPremium, isTrue);
    });

    test(
      'restore without purchases gives free and throws on a failure',
      () async {
        final service = await launch();
        expect((await service.restore()).isPremium, isFalse);
        gateway.failure = const PurchaseException(PurchaseFailureKind.store);
        await expectLater(service.restore(), throwsA(isA<PurchaseException>()));
      },
    );
  });

  group('clock that once ran ahead', () {
    test('the next online answer resets the remembered time', () async {
      final end = DateTime.utc(2026, 12, 20);
      // The clock is far ahead for a while (a wrong date), an answer arrives.
      now = DateTime.utc(2030, 1, 1);
      gateway.entitlement = ServerEntitlement(isActive: true, expiresAt: end);
      await launch();

      // The user fixes the clock; the next launch is online and the server
      // time (2026) replaces the remembered 2030.
      now = DateTime.utc(2026, 11, 24, 12);
      gateway.entitlement = ServerEntitlement(
        isActive: true,
        expiresAt: end,
        serverTime: now,
      );
      await launch();

      // Offline from then on: the paid period still counts.
      gateway.failure = const PurchaseException(PurchaseFailureKind.network);
      final offline = await launch();
      expect(offline.current.isPremium, isTrue);
    });
  });

  group('answers that arrive late', () {
    test('a refresh started before a purchase does not undo it', () async {
      final service = await launch();
      gateway.entitlementGate = Completer<void>();
      final slow = service.refresh(); // will answer "not active"
      await pumpEventQueue();

      gateway.purchaseResult = const GatewayPurchase(
        GatewayPurchaseStatus.purchased,
        _premium,
      );
      await service.purchase('lifetime');
      expect(service.current.isPremium, isTrue);

      gateway.entitlementGate!.complete();
      await slow;
      expect(service.current.isPremium, isTrue);
    });
  });

  group('start-up', () {
    test(
      'without a key the service is disabled and the cache still counts',
      () async {
        gateway.entitlement = until(now.add(const Duration(days: 5)));
        await launch();

        final service = await createPurchaseService(apiKey: '', cache: cache);
        addTearDown(service.dispose);
        expect(service.isAvailable, isFalse);
        expect(service.current.isPremium, isTrue);
        await expectLater(
          service.getOffering(),
          throwsA(isA<PurchaseException>()),
        );
        await expectLater(
          service.purchase('x'),
          throwsA(isA<PurchaseException>()),
        );
        await service.syncOnce();
      },
    );

    test(
      'a store SDK that cannot start leaves a working disabled service',
      () async {
        final service = await createPurchaseService(
          apiKey: 'test-key',
          cache: cache,
          createGateway: (_) async => throw StateError('no SDK'),
        );
        addTearDown(service.dispose);
        expect(service.isAvailable, isFalse);
        expect(service.current.isPremium, isFalse);
      },
    );

    test(
      'with a key the real service starts without waiting for the network',
      () async {
        final service = await createPurchaseService(
          apiKey: 'test-key',
          cache: cache,
          createGateway: (_) async => gateway,
        );
        addTearDown(service.dispose);
        expect(service.isAvailable, isTrue);
      },
    );

    test('a gateway whose service cannot start is released', () async {
      final broken = _BrokenGateway();
      final service = await createPurchaseService(
        apiKey: 'test-key',
        cache: cache,
        createGateway: (_) async => broken,
      );
      addTearDown(service.dispose);
      expect(service.isAvailable, isFalse);
      expect(broken.disposed, isTrue);
    });

    test('an unreadable cache does not stop the start', () async {
      final broken = EntitlementCache(
        openBox: () async => throw StateError('x'),
      );
      final service = RevenueCatPurchaseService(
        gateway: gateway,
        cache: broken,
        clock: Clock(() => now),
      );
      services.add(service);
      gateway.entitlement = _premium;
      await service.start();
      await service.backgroundStart;
      expect(service.current.isPremium, isTrue);
    });
  });
}

/// A gateway whose update stream cannot be opened: the service fails to start.
class _BrokenGateway extends FakeGateway {
  @override
  Stream<ServerEntitlement> get updates => throw StateError('no stream');
}
