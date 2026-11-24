import 'package:pilotiq/src/notifications/notification_service.dart';
import 'package:pilotiq/src/notifications/reminder_planner.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// In-memory [NotificationService]: used by tests and on platforms where the
/// plugin does not exist (the app then simply shows no notifications).
class FakeNotificationService implements NotificationService {
  FakeNotificationService({
    this.permission = NotificationPermission.granted,
    this.permissionAfterRequest,
    this.zone = 'Europe/Warsaw',
  });

  /// Current system permission.
  NotificationPermission permission;

  /// What the system answers to [requestPermission]; null leaves [permission]
  /// as it is.
  NotificationPermission? permissionAfterRequest;

  /// IANA name of the simulated device time zone.
  String zone;

  /// Scheduled reminders by id (a second schedule with the same id replaces
  /// the first one, like the real plugin does).
  final Map<int, PlannedReminder> scheduled = {};

  /// Every call in order: `initialize`, `cancelAll`, `schedule`, `request`,
  /// `openSettings`.
  final List<String> calls = [];

  int requestCount = 0;
  int openSettingsCount = 0;

  /// Makes the next [schedule] / [cancelAll] calls throw.
  Object? failWith;

  ReminderChannel? lastChannel;

  List<PlannedReminder> get scheduledSorted =>
      scheduled.values.toList()..sort((a, b) => a.at.compareTo(b.at));

  @override
  Future<void> initialize() async {
    calls.add('initialize');
    tzdata.initializeTimeZones();
  }

  @override
  Future<tz.Location> localLocation() async {
    await initialize();
    return tz.getLocation(zone);
  }

  @override
  Future<NotificationPermission> permissionStatus() async => permission;

  @override
  Future<NotificationPermission> requestPermission() async {
    calls.add('request');
    requestCount++;
    permission = permissionAfterRequest ?? permission;
    return permission;
  }

  @override
  Future<void> cancelAll() async {
    calls.add('cancelAll');
    final error = failWith;
    if (error != null) throw error;
    scheduled.clear();
  }

  @override
  Future<void> schedule(
    PlannedReminder reminder,
    ReminderChannel channel,
  ) async {
    calls.add('schedule');
    final error = failWith;
    if (error != null) throw error;
    lastChannel = channel;
    scheduled[reminder.id] = reminder;
  }

  @override
  Future<bool> openSystemSettings() async {
    calls.add('openSettings');
    openSettingsCount++;
    return true;
  }
}
