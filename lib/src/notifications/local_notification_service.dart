import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:pilotiq/src/notifications/notification_service.dart';
import 'package:pilotiq/src/notifications/reminder_planner.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

/// True where the notification plugin exists (Android and iOS).
bool get notificationsSupportedHere =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);

/// [NotificationService] on top of `flutter_local_notifications`.
///
/// Reminders are scheduled with `AndroidScheduleMode.inexactAllowWhileIdle`:
/// no exact-alarm permission is needed or declared. The system permission is
/// never requested at start-up (`DarwinInitializationSettings` do not ask);
/// [requestPermission] is called only after an explicit tap of the user.
class LocalNotificationService implements NotificationService {
  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Method channel implemented in `MainActivity` (Android only).
  static const MethodChannel _settingsChannel = MethodChannel(
    'antonchik.anton.pilotiq/system_settings',
  );

  final FlutterLocalNotificationsPlugin _plugin;
  Future<tz.Location>? _init;

  @override
  Future<void> initialize() => localLocation();

  @override
  Future<tz.Location> localLocation() {
    final started = _init ??= _start();
    // A failed start is not remembered: the next call tries again.
    started.then<void>(
      (_) {},
      onError: (Object _) {
        if (identical(_init, started)) _init = null;
      },
    );
    return started;
  }

  Future<tz.Location> _start() async {
    tzdata.initializeTimeZones();
    final location = await _deviceLocation();
    tz.setLocalLocation(location);
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    return location;
  }

  /// The device zone by its IANA id; if the id is unknown to the database, a
  /// fixed offset of the moment (better than a wrong region).
  static Future<tz.Location> _deviceLocation() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      return tz.getLocation(info.identifier);
    } on Object {
      final offset = DateTime.now().timeZoneOffset;
      return tz.Location('device', [tz.minTime], [0], [
        tz.TimeZone(offset, isDst: false, abbreviation: 'LOC'),
      ]);
    }
  }

  @override
  Future<NotificationPermission> permissionStatus() async {
    await initialize();
    final bool? enabled;
    if (Platform.isAndroid) {
      enabled = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.areNotificationsEnabled();
    } else if (Platform.isIOS) {
      enabled =
          (await _plugin
                  .resolvePlatformSpecificImplementation<
                    IOSFlutterLocalNotificationsPlugin
                  >()
                  ?.checkPermissions())
              ?.isEnabled;
    } else {
      enabled = false;
    }
    return enabled == true
        ? NotificationPermission.granted
        : NotificationPermission.denied;
  }

  @override
  Future<NotificationPermission> requestPermission() async {
    await initialize();
    if (Platform.isAndroid) {
      // Android 13+: shows the POST_NOTIFICATIONS dialog; before that it only
      // reports the state.
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, sound: true);
    }
    return permissionStatus();
  }

  @override
  Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAllPendingNotifications();
  }

  @override
  Future<void> schedule(
    PlannedReminder reminder,
    ReminderChannel channel,
  ) async {
    await initialize();
    await _plugin.zonedSchedule(
      id: reminder.id,
      title: reminder.title,
      body: reminder.body,
      scheduledDate: reminder.at,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          ReminderChannel.id,
          channel.name,
          channelDescription: channel.description,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<bool> openSystemSettings() async {
    try {
      if (Platform.isAndroid) {
        return await _settingsChannel.invokeMethod<bool>(
              'openNotificationSettings',
            ) ??
            false;
      }
      if (Platform.isIOS) {
        return await launchUrl(Uri.parse('app-settings:'));
      }
    } on Object catch (e) {
      debugPrint('Opening the system settings failed: $e');
    }
    return false;
  }
}
