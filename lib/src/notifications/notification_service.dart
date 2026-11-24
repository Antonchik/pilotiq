import 'package:pilotiq/src/notifications/reminder_planner.dart';
import 'package:timezone/timezone.dart' as tz;

/// State of the system permission to show notifications.
enum NotificationPermission {
  /// Notifications can be shown.
  granted,

  /// Not granted: never asked, refused, or revoked in the system settings.
  denied,
}

/// Name and description of the Android notification channel, in the language
/// the schedule is built in.
class ReminderChannel {
  const ReminderChannel({required this.name, required this.description});

  static const String id = 'study_reminders';

  final String name;
  final String description;
}

/// The only door to the notification plugin. The real implementation wraps
/// `flutter_local_notifications`; tests and platforms without the plugin use
/// [FakeNotificationService].
abstract class NotificationService {
  /// Prepares the plugin and the time zone data. Safe to call many times.
  Future<void> initialize();

  /// Time zone the user lives in (needed to place reminders on wall-clock
  /// times).
  Future<tz.Location> localLocation();

  /// Current system permission, without asking.
  Future<NotificationPermission> permissionStatus();

  /// Shows the system permission dialog (when the system allows it) and
  /// returns the resulting status.
  Future<NotificationPermission> requestPermission();

  /// Removes every scheduled reminder.
  Future<void> cancelAll();

  /// Removes every scheduled reminder whose id is not in [keep].
  Future<void> cancelExcept(Set<int> keep);

  /// Schedules one reminder (inexact delivery). A reminder with an id that
  /// is already scheduled is replaced.
  Future<void> schedule(PlannedReminder reminder, ReminderChannel channel);

  /// Opens the notification settings of the app in the system. Returns false
  /// when that was not possible.
  Future<bool> openSystemSettings();
}
