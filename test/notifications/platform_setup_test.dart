import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The native projects cannot be built here; these checks read the files the
/// notification plugin needs to be set up in (see its README) and the ones
/// that must stay free of exact-alarm permissions.
void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml')
      .readAsStringSync();

  group('AndroidManifest.xml', () {
    test('declares the notification permissions', () {
      expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
      expect(manifest, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
    });

    test('has no exact-alarm permissions (only inexact alarms are used)', () {
      expect(manifest, isNot(contains('SCHEDULE_EXACT_ALARM')));
      expect(manifest, isNot(contains('USE_EXACT_ALARM')));
      expect(manifest, isNot(contains('USE_FULL_SCREEN_INTENT')));
    });

    test('declares the receivers of the plugin, boot restore included', () {
      expect(
        manifest,
        contains(
          'com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver',
        ),
      );
      final boot = RegExp(
        r'<receiver[^>]*ScheduledNotificationBootReceiver[^>]*>(.*?)</receiver>',
        dotAll: true,
      ).firstMatch(manifest);
      expect(boot, isNotNull);
      for (final action in [
        'android.intent.action.BOOT_COMPLETED',
        'android.intent.action.MY_PACKAGE_REPLACED',
        'android.intent.action.QUICKBOOT_POWERON',
        'com.htc.intent.action.QUICKBOOT_POWERON',
      ]) {
        expect(boot!.group(1), contains(action));
      }
      // Receivers are private to the app.
      final receivers = RegExp(r'<receiver[^>]*>').allMatches(manifest);
      expect(receivers, hasLength(2));
      for (final r in receivers) {
        expect(r.group(0), contains('android:exported="false"'));
      }
    });

    test('the receivers and the permissions sit in the right places', () {
      final application = RegExp(
        r'<application.*</application>',
        dotAll: true,
      ).firstMatch(manifest)!.group(0)!;
      expect(application, contains('ScheduledNotificationBootReceiver'));
      expect(application, isNot(contains('<uses-permission')));
    });
  });

  test('Android build: core library desugaring is enabled', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('isCoreLibraryDesugaringEnabled = true'));
    expect(gradle, contains('coreLibraryDesugaring('));
  });

  test('the Kotlin side answers the settings channel the Dart side calls', () {
    final kotlin = File(
      'android/app/src/main/kotlin/antonchik/anton/pilotiq/MainActivity.kt',
    ).readAsStringSync();
    final dart = File('lib/src/notifications/local_notification_service.dart')
        .readAsStringSync();
    const channel = 'antonchik.anton.pilotiq/system_settings';
    expect(kotlin, contains(channel));
    expect(dart, contains(channel));
    expect(kotlin, contains('openNotificationSettings'));
    expect(dart, contains('openNotificationSettings'));
  });

  group('iOS', () {
    final delegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    test('the notification center delegate is set before the app starts', () {
      final set = delegate.indexOf(
        'UNUserNotificationCenter.current().delegate = self',
      );
      final start = delegate.indexOf('return super.application(');
      expect(set, isNonNegative);
      expect(set, lessThan(start));
      // The implicit-engine template of Flutter stays intact.
      expect(delegate, contains('FlutterImplicitEngineDelegate'));
      expect(delegate, contains('didInitializeImplicitFlutterEngine'));
    });

    test('the permission is not requested at start-up', () {
      final service = File(
        'lib/src/notifications/local_notification_service.dart',
      ).readAsStringSync();
      for (final flag in [
        'requestAlertPermission: false',
        'requestBadgePermission: false',
        'requestSoundPermission: false',
      ]) {
        expect(service, contains(flag));
      }
    });
  });

  test('the plugin is used only through NotificationService', () {
    final offenders = [
      for (final f
          in Directory('lib')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart')))
        if (!f.path.endsWith('local_notification_service.dart') &&
            f.readAsStringSync().contains(
              'package:flutter_local_notifications/',
            ))
          f.path,
    ];
    expect(offenders, isEmpty);
  });

  test('Android uses the inexact schedule mode', () {
    final service = File(
      'lib/src/notifications/local_notification_service.dart',
    ).readAsStringSync();
    expect(service, contains('AndroidScheduleMode.inexactAllowWhileIdle'));
    expect(service, isNot(contains('AndroidScheduleMode.exact')));
    expect(service, isNot(contains('requestExactAlarmsPermission')));
  });
}
