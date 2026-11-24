import 'dart:ui';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/notifications/fake_notification_service.dart';
import 'package:pilotiq/src/notifications/notification_service.dart';
import 'package:pilotiq/src/notifications/providers.dart';
import 'package:pilotiq/src/progress/progress_repository.dart';
import 'package:pilotiq/src/progress/providers.dart';
import 'package:pilotiq/src/progress/user_settings.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../bank/memory_hive.dart';

void main() {
  late FakeNotificationService service;
  late ProgressRepository repository;
  late MemoryReminderPrefsStore prefs;
  late ProviderContainer container;
  late tz.TZDateTime now;
  var locale = const Locale('en');

  setUpAll(tzdata.initializeTimeZones);

  Future<void> setConfig(Map<String, Object?> values) async {
    final box = await openMemoryBox('config');
    for (final e in values.entries) {
      await box.put(e.key, e.value);
    }
  }

  ProviderContainer makeContainer() {
    final c = ProviderContainer(
      overrides: [
        progressRepositoryProvider.overrideWithValue(repository),
        notificationServiceProvider.overrideWithValue(service),
        reminderPrefsProvider.overrideWithValue(prefs),
        reminderLocaleProvider.overrideWithValue(() => locale),
        clockProvider.overrideWithValue(Clock(() => now)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  ReminderCoordinator coordinator() =>
      container.read(reminderCoordinatorProvider.notifier);

  setUp(() async {
    service = FakeNotificationService();
    prefs = MemoryReminderPrefsStore();
    repository = memoryProgressRepository();
    locale = const Locale('en');
    await service.initialize();
    now = tz.TZDateTime(tz.getLocation('Europe/Warsaw'), 2026, 11, 23, 10);
    await setConfig({'onboardingDone': true});
  });
  tearDown(() async => Hive.close());

  Future<void> useSettings(Map<String, Object?> values) async {
    await setConfig(values);
    container = makeContainer();
    // The listener of the coordinator lives as long as the coordinator.
    container.read(reminderCoordinatorProvider);
    await container.read(userSettingsProvider.future);
  }

  test(
    'reminders on: the schedule is set with the texts of the language',
    () async {
      await useSettings({'reminderTime': '19:00'});
      await coordinator().reschedule(force: true);

      expect(service.scheduled, hasLength(14));
      expect(
        container.read(reminderCoordinatorProvider),
        const ReminderStatus(ReminderPhase.scheduled, 14),
      );
      expect(
        service.scheduledSorted.first.at,
        tz.TZDateTime(tz.getLocation('Europe/Warsaw'), 2026, 11, 23, 19),
      );
      expect(service.scheduledSorted.first.title, 'Time to study');
      expect(service.scheduledSorted.first.body, '20 answers to today\'s goal');
      expect(service.lastChannel!.name, 'Study reminders');
    },
  );

  test(
    'the language of the device decides, and a change rebuilds the schedule',
    () async {
      await useSettings({
        'reminderTime': '19:00',
        'examDate': '2026-12-03',
        'dailyGoal': 22,
      });
      locale = const Locale('pl', 'PL');
      await coordinator().reschedule(force: true);
      var first = service.scheduledSorted.first;
      expect(first.title, 'Czas na naukę');
      expect(
        first.body,
        'Do egzaminu: 10 dni · Do dzisiejszego celu: 22 odpowiedzi',
      );
      expect(service.lastChannel!.name, 'Przypomnienia o nauce');

      // The device language is switched; the next start rebuilds the schedule.
      locale = const Locale('en');
      container.dispose();
      container = makeContainer();
      await coordinator().reschedule(force: true);
      first = service.scheduledSorted.first;
      expect(first.title, 'Time to study');
      expect(first.body, '10 days to the exam · 22 answers to today\'s goal');
      expect(
        service.scheduled,
        hasLength(service.scheduled.keys.toSet().length),
      );
    },
  );

  test('an unsupported language falls back to English', () async {
    await useSettings({'reminderTime': '19:00'});
    locale = const Locale('de');
    await coordinator().reschedule(force: true);
    expect(service.scheduledSorted.first.title, 'Time to study');
  });

  test(
    'changing the settings replaces the schedule and drops the leftovers',
    () async {
      await useSettings({'reminderTime': '19:00'});
      await coordinator().reschedule(force: true);
      service.calls.clear();

      await container
          .read(userSettingsProvider.notifier)
          .change((s) => s.copyWith(reminderTime: const ReminderTime(8, 30)));
      await coordinator().reschedule();

      // Nothing is cancelled up front: reminders are replaced by id and only
      // the leftovers are removed at the end.
      expect(service.calls, isNot(contains('cancelAll')));
      expect(service.calls.where((c) => c == 'schedule'), hasLength(13));
      expect(
        service.calls.where((c) => c != 'initialize').last,
        'cancelExcept',
      );
      // Tomorrow: today's 08:30 has passed at 10:00.
      expect(service.scheduledSorted.first.at.hour, 8);
      expect(service.scheduledSorted.first.at.minute, 30);
      expect(service.scheduledSorted.first.at.day, 24);
      expect(service.scheduled, hasLength(13));
    },
  );

  test(
    'changing the exam date or the goal also rebuilds the schedule',
    () async {
      await useSettings({'reminderTime': '19:00'});
      await coordinator().reschedule(force: true);
      service.calls.clear();
      await container
          .read(userSettingsProvider.notifier)
          .change((s) => s.copyWith(examDate: DateTime(2026, 11, 26)));
      await coordinator().reschedule();
      expect(service.calls, contains('cancelExcept'));
      expect(service.scheduled, hasLength(4));

      service.calls.clear();
      await container
          .read(userSettingsProvider.notifier)
          .change((s) => s.copyWith(dailyGoal: 40));
      await coordinator().reschedule();
      expect(service.calls, contains('cancelExcept'));
      expect(service.scheduledSorted.first.body, contains('40'));
    },
  );

  test('switching the reminders off clears the schedule', () async {
    await useSettings({'reminderTime': '19:00'});
    await coordinator().reschedule(force: true);
    expect(service.scheduled, isNotEmpty);

    await container
        .read(userSettingsProvider.notifier)
        .change((s) => s.copyWith(clearReminderTime: true));
    await coordinator().reschedule();
    expect(service.scheduled, isEmpty);
    expect(
      container.read(reminderCoordinatorProvider).phase,
      ReminderPhase.off,
    );
  });

  test('reminders never set: nothing is scheduled', () async {
    await useSettings({});
    await coordinator().reschedule(force: true);
    expect(service.scheduled, isEmpty);
    expect(service.calls.where((c) => c == 'schedule'), isEmpty);
    expect(
      container.read(reminderCoordinatorProvider).phase,
      ReminderPhase.off,
    );
  });

  test('without the system permission nothing is scheduled', () async {
    service.permission = NotificationPermission.denied;
    await useSettings({'reminderTime': '19:00'});
    await coordinator().reschedule(force: true);
    expect(service.scheduled, isEmpty);
    expect(service.calls.where((c) => c == 'schedule'), isEmpty);
    expect(service.requestCount, 0, reason: 'never asks by itself');
    expect(
      container.read(reminderCoordinatorProvider).phase,
      ReminderPhase.permissionMissing,
    );

    // Allowed in the system settings: the next run schedules.
    service.permission = NotificationPermission.granted;
    await coordinator().reschedule();
    expect(service.scheduled, hasLength(14));
  });

  test('a permission revoked later clears the schedule', () async {
    await useSettings({'reminderTime': '19:00'});
    await coordinator().reschedule(force: true);
    expect(service.scheduled, isNotEmpty);
    service.permission = NotificationPermission.denied;
    await coordinator().reschedule();
    expect(service.scheduled, isEmpty);
    expect(
      container.read(reminderCoordinatorProvider).phase,
      ReminderPhase.permissionMissing,
    );
  });

  test('reaching the goal removes today and keeps the other days', () async {
    await useSettings({'reminderTime': '19:00'});
    await coordinator().reschedule(force: true);
    expect(service.scheduledSorted.first.at.day, 23);

    for (var i = 0; i < 20; i++) {
      await repository.recordAnswer(
        Licence.ppla,
        'PL010-000${1 + i % 4}',
        true,
        now,
      );
    }
    await coordinator().reschedule();
    expect(service.scheduledSorted.first.at.day, 24);
    expect(service.scheduled, hasLength(13));
  });

  test('a new day moves the window forward', () async {
    await useSettings({'reminderTime': '19:00'});
    await coordinator().reschedule(force: true);
    now = now.add(const Duration(days: 1));
    await coordinator().reschedule();
    expect(service.scheduledSorted.first.at.day, 24);
    expect(service.scheduledSorted.last.at.day, 7);
    expect(service.scheduled, hasLength(14));
  });

  test('planning again does not create duplicates', () async {
    await useSettings({'reminderTime': '19:00', 'examDate': '2026-12-03'});
    await coordinator().reschedule(force: true);
    final first = service.scheduledSorted;
    await coordinator().reschedule(force: true);
    await coordinator().reschedule(force: true);
    expect(service.scheduledSorted, first);
    expect(service.scheduled, hasLength(first.length));

    // Without force an identical plan is not even sent to the plugin.
    service.calls.clear();
    await coordinator().reschedule();
    expect(
      service.calls.where((c) => c == 'schedule' || c == 'cancelExcept'),
      isEmpty,
    );
  });

  test('concurrent requests are run one after another', () async {
    await useSettings({'reminderTime': '19:00'});
    await Future.wait([
      coordinator().reschedule(force: true),
      coordinator().reschedule(force: true),
      coordinator().reschedule(force: true),
    ]);
    expect(service.scheduled, hasLength(14));
    // Every run is its schedules followed by one cancelExcept: never interleaved.
    final calls = service.calls
        .where((c) => c == 'schedule' || c == 'cancelExcept')
        .map((c) => c == 'schedule' ? 's' : 'x')
        .join();
    expect(calls, matches(RegExp(r'^(s{14}x)+$')));
  });

  test('a failing plugin does not throw and shows as "failed"', () async {
    await useSettings({'reminderTime': '19:00'});
    service.failWith = StateError('no plugin');
    await coordinator().reschedule(force: true);
    expect(
      container.read(reminderCoordinatorProvider).phase,
      ReminderPhase.failed,
    );

    service.failWith = null;
    await coordinator().reschedule(force: true);
    expect(
      container.read(reminderCoordinatorProvider).phase,
      ReminderPhase.scheduled,
    );
    expect(service.scheduled, hasLength(14));
  });

  test('a failure on one reminder leaves no hole and is retried', () async {
    await useSettings({'reminderTime': '19:00'});
    await coordinator().reschedule(force: true);
    final before = service.scheduledSorted;
    expect(before, hasLength(14));

    // The next day: one reminder in the middle is rejected by the system.
    now = now.add(const Duration(days: 1));
    final broken = before[5].id;
    service.failIds.add(broken);
    await coordinator().reschedule();
    expect(
      container.read(reminderCoordinatorProvider).phase,
      ReminderPhase.failed,
    );
    // Everything else is in place, including the days that came before and
    // after the failing one; the new last day was still added.
    expect(
      service.scheduled.containsKey(broken),
      isTrue,
      reason: 'the old reminder with that id stays until replaced',
    );
    expect(service.scheduled, hasLength(14));
    expect(service.calls.where((c) => c == 'cancelAll'), isEmpty);

    // Retried by the next run without force.
    service.failIds.clear();
    await coordinator().reschedule();
    expect(
      container.read(reminderCoordinatorProvider),
      const ReminderStatus(ReminderPhase.scheduled, 14),
    );
    expect(service.scheduledSorted.first.at.day, 24);
  });

  test('a rejection of every reminder does not throw', () async {
    await useSettings({'reminderTime': '19:00'});
    await coordinator().reschedule(force: true);
    now = now.add(const Duration(days: 1));
    service.failIds.addAll(service.scheduled.keys);
    await coordinator().reschedule();
    expect(
      container.read(reminderCoordinatorProvider).phase,
      ReminderPhase.failed,
    );
  });

  test('a reminder closer than a minute to now is not scheduled', () async {
    await useSettings({'reminderTime': '19:00'});
    now = tz.TZDateTime(
      tz.getLocation('Europe/Warsaw'),
      2026,
      11,
      23,
      18,
      59,
      30,
    );
    await coordinator().reschedule(force: true);
    expect(service.scheduledSorted.first.at.day, 24);
    expect(service.scheduled, hasLength(13));
    expect(
      container.read(reminderCoordinatorProvider).phase,
      ReminderPhase.scheduled,
    );

    now = tz.TZDateTime(
      tz.getLocation('Europe/Warsaw'),
      2026,
      11,
      23,
      18,
      58,
      30,
    );
    await coordinator().reschedule();
    expect(service.scheduledSorted.first.at.day, 23);
  });

  test(
    'reaching the goal while the app is open removes today at once',
    () async {
      await useSettings({'reminderTime': '19:00'});
      await coordinator().reschedule(force: true);
      expect(service.scheduledSorted.first.at.day, 23);

      // Nothing changed: the check does not touch the plugin.
      service.calls.clear();
      await coordinator().checkProgress();
      expect(service.calls, isEmpty);

      for (var i = 0; i < 19; i++) {
        await repository.recordAnswer(
          Licence.ppla,
          'PL010-000${1 + i % 4}',
          true,
          now,
        );
      }
      await coordinator().checkProgress();
      expect(service.calls, isEmpty, reason: 'goal not reached yet');

      await repository.recordAnswer(Licence.ppla, 'PL010-0001', true, now);
      await coordinator().checkProgress();
      expect(service.scheduledSorted.first.at.day, 24);
      expect(service.scheduled, hasLength(13));
    },
  );

  test('the check does nothing while the reminders are off', () async {
    await useSettings({});
    service.calls.clear();
    await coordinator().checkProgress();
    expect(service.calls, isEmpty);
  });

  group('language of the reminders', () {
    test('follows the whole preferred list, like the interface', () {
      expect(
        resolveDeviceLocale(const [Locale('de'), Locale('pl')]),
        const Locale('pl'),
      );
      expect(
        resolveDeviceLocale(const [Locale('en', 'US'), Locale('pl')])
            .languageCode,
        'en',
      );
      expect(
        resolveDeviceLocale(const [Locale('pl', 'PL')]).languageCode,
        'pl',
      );
      expect(resolveDeviceLocale(const [Locale('de')]).languageCode, 'en');
      expect(resolveDeviceLocale(const []).languageCode, 'en');
    });
  });

  group('permission in context', () {
    test('enable asks once, stores the time when allowed', () async {
      service.permission = NotificationPermission.denied;
      service.permissionAfterRequest = NotificationPermission.granted;
      await useSettings({});
      final result = await coordinator().enable(const ReminderTime(7, 15));
      expect(result, ReminderEnableResult.enabled);
      expect(service.requestCount, 1);
      expect(Hive.box<dynamic>('config').get('reminderTime'), '07:15');
      await coordinator().reschedule();
      expect(service.scheduled, isNotEmpty);
      expect(await prefs.permissionRefused(), isFalse);
    });

    test('enable does not ask when the permission is already there', () async {
      await useSettings({});
      final result = await coordinator().enable(defaultReminderTime);
      expect(result, ReminderEnableResult.enabled);
      expect(service.requestCount, 0);
    });

    test('a refusal is remembered and the time is not stored', () async {
      service.permission = NotificationPermission.denied;
      await useSettings({});
      final result = await coordinator().enable(defaultReminderTime);
      expect(result, ReminderEnableResult.permissionDenied);
      expect(await prefs.permissionRefused(), isTrue);
      expect(Hive.box<dynamic>('config').get('reminderTime'), isNull);
      await coordinator().reschedule(force: true);
      expect(service.scheduled, isEmpty);
      expect(service.requestCount, 1, reason: 'start-up never asks again');
    });

    test(
      'the refusal is forgotten once the system allows notifications',
      () async {
        await prefs.setPermissionRefused(true);
        await useSettings({});
        await coordinator().reschedule(force: true);
        expect(await prefs.permissionRefused(), isFalse);
      },
    );
  });
}
