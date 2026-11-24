import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilotiq/src/notifications/local_notification_service.dart';
import 'package:pilotiq/src/notifications/notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('the service loads the full time zone database', () {
    final source = File('lib/src/notifications/local_notification_service.dart')
        .readAsStringSync();
    expect(source, contains('timezone/data/latest_all.dart'));
    expect(source, isNot(contains('timezone/data/latest.dart')));
  });

  test('old and alias zone names Android reports are resolved', () async {
    for (final id in [
      'Europe/Kiev',
      'Asia/Calcutta',
      'US/Pacific',
      'UTC',
      'GMT',
      'America/Buenos_Aires',
      'Europe/Warsaw',
    ]) {
      final location = await LocalNotificationService.resolveDeviceLocation(
        () async => id,
        Duration.zero,
      );
      expect(location.name, id);
    }
  });

  group('fallback zone', () {
    test('has a real IANA name and the right offset', () {
      final cases = <Duration, String>{
        const Duration(hours: 3): 'Etc/GMT-3',
        const Duration(hours: -5): 'Etc/GMT+5',
        const Duration(hours: 14): 'Etc/GMT-14',
        const Duration(hours: -12): 'Etc/GMT+12',
        Duration.zero: 'Etc/UTC',
        const Duration(hours: 5, minutes: 30): 'Etc/UTC',
      };
      cases.forEach((offset, name) {
        final location = LocalNotificationService.fallbackLocation(offset);
        expect(location.name, name);
        if (name != 'Etc/UTC') {
          final at = tz.TZDateTime(location, 2026, 6, 1, 12);
          expect(at.timeZoneOffset, offset);
        }
        expect(location.name, isNot('device'));
        // The native side must be able to find it again.
        expect(tz.getLocation(location.name), same(location));
      });
    });

    test('is used when the id is unknown or cannot be read', () async {
      final unknown = await LocalNotificationService.resolveDeviceLocation(
        () async => 'Mars/Olympus',
        const Duration(hours: 2),
      );
      expect(unknown.name, 'Etc/GMT-2');
      final failing = await LocalNotificationService.resolveDeviceLocation(
        () async => throw StateError('no plugin'),
        const Duration(hours: -3),
      );
      expect(failing.name, 'Etc/GMT+3');
    });
  });

  group('switched-off notification channel', () {
    AndroidNotificationChannel channel(String id, Importance importance) =>
        AndroidNotificationChannel(id, 'name', importance: importance);

    test('is recognised', () {
      expect(
        LocalNotificationService.channelDisabled([
          channel('other', Importance.defaultImportance),
          channel(ReminderChannel.id, Importance.none),
        ]),
        isTrue,
      );
    });

    test('an enabled, missing or unreadable channel is not a problem', () {
      expect(
        LocalNotificationService.channelDisabled([
          channel(ReminderChannel.id, Importance.defaultImportance),
          channel('other', Importance.none),
        ]),
        isFalse,
      );
      expect(LocalNotificationService.channelDisabled(const []), isFalse);
      expect(LocalNotificationService.channelDisabled(null), isFalse);
    });
  });
}
