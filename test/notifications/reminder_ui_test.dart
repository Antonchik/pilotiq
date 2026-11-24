import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pilotiq/src/home/home.dart';
import 'package:pilotiq/src/notifications/fake_notification_service.dart';
import 'package:pilotiq/src/notifications/notification_service.dart';
import 'package:pilotiq/src/notifications/providers.dart';
import 'package:pilotiq/src/onboarding/onboarding_screen.dart';

import '../dashboard/dashboard_helpers.dart';

void main() {
  AppHarness.registerSetUp();

  late FakeNotificationService service;
  late MemoryReminderPrefsStore prefs;

  setUp(() {
    service = FakeNotificationService();
    prefs = MemoryReminderPrefsStore();
  });

  List<Override> reminderOverrides() => [
    remindersSupportedProvider.overrideWithValue(true),
    notificationServiceProvider.overrideWithValue(service),
    reminderPrefsProvider.overrideWithValue(prefs),
  ];

  Future<void> openProfile(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('tab_profile')));
    await tester.pumpAndSettle();
  }

  Future<void> toOnboardingReminders(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding_skip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding_next')));
    await tester.pumpAndSettle();
  }

  group('onboarding page', () {
    testWidgets('is the last step; no permission is asked before the tap', (
      tester,
    ) async {
      final h = AppHarness();
      await h.pump(tester, extraOverrides: reminderOverrides());
      expect(find.text('Step 1 of 4'), findsOneWidget);
      await toOnboardingReminders(tester);

      expect(find.text('Step 4 of 4'), findsOneWidget);
      expect(find.text('When should we remind you?'), findsOneWidget);
      expect(find.byKey(const Key('onboarding_reminders_enable')), findsOne);
      expect(service.requestCount, 0);

      // "Finish" without enabling: the onboarding is done, no reminders.
      await tester.tap(find.byKey(const Key('onboarding_finish')));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(Hive.box<dynamic>('config').get('reminderTime'), isNull);
      expect(service.requestCount, 0);
      expect(service.scheduled, isEmpty);
    });

    testWidgets('the tap asks, the choice is saved with the other settings', (
      tester,
    ) async {
      service.permission = NotificationPermission.denied;
      service.permissionAfterRequest = NotificationPermission.granted;
      final h = AppHarness();
      await h.pump(tester, extraOverrides: reminderOverrides());
      await toOnboardingReminders(tester);

      await tester.tap(find.byKey(const Key('onboarding_reminders_enable')));
      await tester.pumpAndSettle();
      expect(service.requestCount, 1);
      expect(find.byKey(const Key('onboarding_reminder_time')), findsOne);
      expect(find.textContaining('7:00'), findsNWidgets(2));

      await tester.tap(find.byKey(const Key('onboarding_finish')));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(Hive.box<dynamic>('config').get('reminderTime'), '19:00');
      expect(service.scheduled, isNotEmpty);
      expect(await prefs.permissionRefused(), isFalse);
    });

    testWidgets('the time can be changed in the standard time dialog', (
      tester,
    ) async {
      final h = AppHarness();
      await h.pump(tester, extraOverrides: reminderOverrides());
      await toOnboardingReminders(tester);
      await tester.tap(find.byKey(const Key('onboarding_reminders_enable')));
      await tester.pumpAndSettle();
      expect(service.requestCount, 0, reason: 'already allowed');

      await tester.tap(find.byKey(const Key('onboarding_reminder_time')));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.textContaining('7:00'), findsNWidgets(2));

      await tester.tap(find.byKey(const Key('onboarding_reminders_off')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('onboarding_reminders_enable')), findsOne);
    });

    testWidgets('a refusal does not block the onboarding and is remembered', (
      tester,
    ) async {
      service.permission = NotificationPermission.denied;
      final h = AppHarness();
      await h.pump(tester, extraOverrides: reminderOverrides());
      await toOnboardingReminders(tester);

      await tester.tap(find.byKey(const Key('onboarding_reminders_enable')));
      await tester.pumpAndSettle();
      expect(service.requestCount, 1);
      expect(find.byKey(const Key('onboarding_reminders_denied')), findsOne);
      expect(await prefs.permissionRefused(), isTrue);

      await tester.tap(
        find.byKey(const Key('onboarding_reminders_open_settings')),
      );
      await tester.pumpAndSettle();
      expect(service.openSettingsCount, 1);

      await tester.tap(find.byKey(const Key('onboarding_finish')));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      final config = Hive.box<dynamic>('config');
      expect(config.get('onboardingDone'), true);
      expect(config.get('reminderTime'), isNull);
      expect(service.scheduled, isEmpty);
      expect(service.requestCount, 1, reason: 'not asked again');
    });
  });

  group('settings section', () {
    testWidgets('is hidden where reminders do not exist', (tester) async {
      final h = AppHarness();
      await h.seedConfig();
      await h.pump(tester);
      await openProfile(tester);
      expect(find.byKey(const Key('settings_reminders_switch')), findsNothing);
    });

    testWidgets('the switch asks in context, saves and schedules', (
      tester,
    ) async {
      service.permission = NotificationPermission.denied;
      service.permissionAfterRequest = NotificationPermission.granted;
      final h = AppHarness();
      await h.seedConfig();
      await h.pump(tester, extraOverrides: reminderOverrides());
      expect(service.requestCount, 0, reason: 'nothing at start-up');
      await openProfile(tester);
      expect(service.requestCount, 0);

      await tester.tap(find.byKey(const Key('settings_reminders_switch')));
      await tester.pumpAndSettle();
      expect(service.requestCount, 1);
      expect(Hive.box<dynamic>('config').get('reminderTime'), '19:00');
      expect(find.byKey(const Key('settings_reminder_time')), findsOne);
      expect(find.text('Every day at 7:00 PM'), findsOneWidget);
      expect(service.scheduled, hasLength(greaterThanOrEqualTo(13)));
    });

    testWidgets(
      'a refusal keeps the switch off and offers the system settings',
      (tester) async {
        service.permission = NotificationPermission.denied;
        final h = AppHarness();
        await h.seedConfig();
        await h.pump(tester, extraOverrides: reminderOverrides());
        await openProfile(tester);

        await tester.tap(find.byKey(const Key('settings_reminders_switch')));
        await tester.pumpAndSettle();
        expect(Hive.box<dynamic>('config').get('reminderTime'), isNull);
        expect(find.byKey(const Key('settings_reminder_time')), findsNothing);
        expect(find.byKey(const Key('settings_reminders_blocked')), findsOne);
        expect(service.scheduled, isEmpty);

        await tester.tap(
          find.byKey(const Key('settings_reminders_open_settings')),
        );
        await tester.pumpAndSettle();
        expect(service.openSettingsCount, 1);
      },
    );

    testWidgets('a permission revoked in the system is shown', (tester) async {
      service.permission = NotificationPermission.denied;
      final h = AppHarness();
      await h.seedConfig({'reminderTime': '07:30'});
      await h.pump(tester, extraOverrides: reminderOverrides());
      await openProfile(tester);

      expect(find.byKey(const Key('settings_reminders_blocked')), findsOne);
      expect(find.text('Every day at 7:30 AM'), findsOneWidget);
      expect(service.scheduled, isEmpty);
      expect(service.requestCount, 0);
    });

    testWidgets('the switch off clears the schedule', (tester) async {
      final h = AppHarness();
      await h.seedConfig({'reminderTime': '07:30'});
      await h.pump(tester, extraOverrides: reminderOverrides());
      expect(service.scheduled, isNotEmpty);
      await openProfile(tester);

      await tester.tap(find.byKey(const Key('settings_reminders_switch')));
      await tester.pumpAndSettle();
      expect(Hive.box<dynamic>('config').get('reminderTime'), isNull);
      expect(service.scheduled, isEmpty);
      expect(find.byKey(const Key('settings_reminder_time')), findsNothing);
    });

    testWidgets('a failed scheduling is shown and can be repeated', (
      tester,
    ) async {
      service.failWith = StateError('boom');
      final h = AppHarness();
      await h.seedConfig({'reminderTime': '07:30'});
      await h.pump(tester, extraOverrides: reminderOverrides());
      await openProfile(tester);
      expect(find.byKey(const Key('settings_reminders_failed')), findsOne);
      // The app is alive and the UI usable.
      expect(find.byType(HomeScreen), findsOneWidget);

      service.failWith = null;
      await tester.tap(find.byKey(const Key('settings_reminders_retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settings_reminders_failed')), findsNothing);
      expect(service.scheduled, isNotEmpty);
    });

    testWidgets('the time dialog opens and closes', (tester) async {
      final h = AppHarness();
      await h.seedConfig({'reminderTime': '07:30'});
      await h.pump(tester, extraOverrides: reminderOverrides());
      await openProfile(tester);
      await tester.tap(find.byKey(const Key('settings_reminder_time')));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(Hive.box<dynamic>('config').get('reminderTime'), '07:30');
    });
  });

  testWidgets('the app runs with the default (plugin-less) service', (
    tester,
  ) async {
    final h = AppHarness();
    await h.seedConfig({'reminderTime': '07:30'});
    await h.pump(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('a service that always throws does not break the start', (
    tester,
  ) async {
    service.failWith = StateError('no plugin');
    final h = AppHarness();
    await h.seedConfig({'reminderTime': '07:30'});
    await h.pump(tester, extraOverrides: reminderOverrides());
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
