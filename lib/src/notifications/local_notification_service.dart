import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:pilotiq/src/notifications/notification_service.dart';
import 'package:pilotiq/src/notifications/reminder_planner.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
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

  /// The device zone by its IANA id (the full database knows the old names
  /// too: Europe/Kiev, Asia/Calcutta, US/Pacific, UTC, ...). If the id is
  /// unknown or cannot be read, a zone with a real IANA name and the current
  /// offset is used (never an invented name: the native code needs a valid
  /// one).
  static Future<tz.Location> _deviceLocation() => resolveDeviceLocation(
    () async => (await FlutterTimezone.getLocalTimezone()).identifier,
    DateTime.now().timeZoneOffset,
  );

  /// See [_deviceLocation]; the time zone database must be initialised.
  @visibleForTesting
  static Future<tz.Location> resolveDeviceLocation(
    Future<String> Function() readId,
    Duration offset,
  ) async {
    try {
      return tz.getLocation(await readId());
    } on Object {
      return fallbackLocation(offset);
    }
  }

  /// `Etc/GMT-3` for +03:00 (the sign of the Etc zones is inverted), or
  /// `Etc/UTC` for offsets that are not whole hours or out of range.
  @visibleForTesting
  static tz.Location fallbackLocation(Duration offset) {
    final hours = offset.inMinutes / 60;
    if (offset.inMinutes % 60 != 0 || hours < -12 || hours > 14) {
      return tz.getLocation('Etc/UTC');
    }
    final h = hours.toInt();
    if (h == 0) return tz.getLocation('Etc/UTC');
    return tz.getLocation('Etc/GMT${h > 0 ? '-' : '+'}${h.abs()}');
  }

  /// True when the reminder channel exists and the user has switched it off.
  @visibleForTesting
  static bool channelDisabled(List<AndroidNotificationChannel>? channels) =>
      channels?.any(
        (c) => c.id == ReminderChannel.id && c.importance == Importance.none,
      ) ??
      false;

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
      if (enabled == true) {
        // The user can also switch off the channel of the reminders alone.
        final channels = await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.getNotificationChannels();
        if (channelDisabled(channels)) {
          return NotificationPermission.denied;
        }
      }
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
  Future<void> cancelExcept(Set<int> keep) async {
    await initialize();
    for (final pending in await _plugin.pendingNotificationRequests()) {
      if (!keep.contains(pending.id)) await _plugin.cancel(id: pending.id);
    }
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
