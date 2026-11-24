import 'dart:async';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/notifications/fake_notification_service.dart';
import 'package:pilotiq/src/notifications/local_notification_service.dart';
import 'package:pilotiq/src/notifications/notification_service.dart';
import 'package:pilotiq/src/notifications/reminder_planner.dart';
import 'package:pilotiq/src/progress/providers.dart';
import 'package:pilotiq/src/progress/user_settings.dart';

/// Default time offered when the reminders are switched on.
const ReminderTime defaultReminderTime = ReminderTime(19, 0);

/// Whether reminders exist on this platform. Off on the desktop, the web and
/// in tests (they override it): the settings section and the onboarding page
/// are then not shown.
final remindersSupportedProvider = Provider<bool>(
  (ref) => notificationsSupportedHere,
);

/// The notification plugin behind its interface. Without the plugin (any
/// platform other than Android and iOS) the in-memory fake is used, so the
/// app never fails because of it.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => notificationsSupportedHere
      ? LocalNotificationService()
      : FakeNotificationService(),
);

/// Locale the reminder texts are written in: the language of the device,
/// read at the moment of scheduling (a function, so it is never stale).
final reminderLocaleProvider = Provider<Locale Function()>(
  (ref) =>
      () => PlatformDispatcher.instance.locale,
);

/// Small flags of the reminders that are not user settings.
abstract class ReminderPrefsStore {
  /// The user refused the system permission (so it is not asked for again
  /// without a tap of the user).
  Future<bool> permissionRefused();

  Future<void> setPermissionRefused(bool value);
}

class MemoryReminderPrefsStore implements ReminderPrefsStore {
  bool _refused = false;

  @override
  Future<bool> permissionRefused() async => _refused;

  @override
  Future<void> setPermissionRefused(bool value) async => _refused = value;
}

/// Keeps the flag in the Hive box `reminder_prefs`. Storage errors are not
/// fatal: the flag is then simply not remembered.
class HiveReminderPrefsStore implements ReminderPrefsStore {
  static const String boxName = 'reminder_prefs';
  static const String _key = 'permissionRefused';

  Future<Box<dynamic>> _box() => Hive.openBox<dynamic>(boxName);

  @override
  Future<bool> permissionRefused() async {
    try {
      return (await _box()).get(_key) == true;
    } on Object catch (e) {
      debugPrint('Reading the reminder flags failed: $e');
      return false;
    }
  }

  @override
  Future<void> setPermissionRefused(bool value) async {
    try {
      await (await _box()).put(_key, value);
    } on Object catch (e) {
      debugPrint('Saving the reminder flags failed: $e');
    }
  }
}

final reminderPrefsProvider = Provider<ReminderPrefsStore>(
  (ref) => notificationsSupportedHere
      ? HiveReminderPrefsStore()
      : MemoryReminderPrefsStore(),
);

/// Whether the user has refused the system permission before.
final permissionRefusedProvider = FutureProvider<bool>(
  (ref) => ref.watch(reminderPrefsProvider).permissionRefused(),
);

/// Reminder texts from the generated localisations.
class LocalizedReminderTexts implements ReminderTexts {
  const LocalizedReminderTexts(this.local);

  final AppLocalizations local;

  static String _join(List<String> parts) => parts.join(' · ');

  @override
  ReminderMessage study({
    required int remaining,
    int? daysToExam,
    int dueQuestions = 0,
  }) => ReminderMessage(
    title: local.reminderStudyTitle,
    body: _join([
      if (daysToExam != null && daysToExam > 0)
        local.reminderDaysToExam(daysToExam),
      if (dueQuestions > 0) local.reminderDueQuestions(dueQuestions),
      if (remaining > 0) local.reminderGoalLeft(remaining),
    ]),
  );

  @override
  ReminderMessage examWeek({required int remaining}) => ReminderMessage(
    title: local.reminderExamWeekTitle,
    body: local.reminderGoalLeft(remaining),
  );

  @override
  ReminderMessage examEve() => ReminderMessage(
    title: local.reminderExamEveTitle,
    body: local.reminderExamEveBody,
  );

  @override
  ReminderMessage afterExam() => ReminderMessage(
    title: local.reminderAfterExamTitle,
    body: local.reminderAfterExamBody,
  );
}

/// The supported locale that matches [locale] (English otherwise).
Locale resolveReminderLocale(Locale locale) =>
    AppLocalizations.supportedLocales.firstWhere(
      (s) => s.languageCode == locale.languageCode,
      orElse: () => const Locale('en'),
    );

enum ReminderPhase {
  /// Nothing has been planned yet in this run of the app.
  idle,

  /// Reminders are switched off; the schedule is empty.
  off,

  /// The schedule is set ([ReminderStatus.count] notifications).
  scheduled,

  /// Switched on, but the system does not allow notifications.
  permissionMissing,

  /// Switched on, but scheduling failed.
  failed,
}

class ReminderStatus {
  const ReminderStatus(this.phase, [this.count = 0]);

  final ReminderPhase phase;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is ReminderStatus && other.phase == phase && other.count == count;

  @override
  int get hashCode => Object.hash(phase, count);

  @override
  String toString() => 'ReminderStatus($phase, $count)';
}

/// Result of [ReminderCoordinator.enable].
enum ReminderEnableResult { enabled, permissionDenied, saveFailed }

/// Keeps the schedule of the notifications in line with the settings, the
/// day's progress, the clock, the language and the system permission.
///
/// Planning is done by [planReminders]; this class only gathers its input and
/// hands the result to the [NotificationService]. Runs are queued one after
/// another and never throw: a failure is logged and shown as
/// [ReminderPhase.failed].
class ReminderCoordinator extends Notifier<ReminderStatus> {
  Future<void> _tail = Future<void>.value();
  String? _lastSignature;

  @override
  ReminderStatus build() {
    ref.listen<AsyncValue<UserSettings>>(userSettingsProvider, (
      previous,
      next,
    ) {
      final before = previous?.value;
      final after = next.value;
      if (before == null || after == null) return;
      if (_relevant(before) != _relevant(after)) unawaited(reschedule());
    });
    return const ReminderStatus(ReminderPhase.idle);
  }

  static Object _relevant(UserSettings s) =>
      (s.reminderTime, s.examDate, s.dailyGoal, s.licence);

  /// Rebuilds the schedule. Without [force] nothing is sent to the plugin
  /// when the plan is identical to the one already set in this run.
  Future<void> reschedule({bool force = false}) {
    final run = _tail.then((_) => _run(force));
    _tail = run;
    return run;
  }

  Future<void> _run(bool force) async {
    try {
      final settings = await ref.read(userSettingsProvider.future);
      if (!ref.mounted) return;
      final service = ref.read(notificationServiceProvider);
      final prefs = ref.read(reminderPrefsProvider);
      final repository = ref.read(progressRepositoryProvider);
      final clock = ref.read(clockProvider);
      final deviceLocale = ref.read(reminderLocaleProvider);

      if (settings.reminderTime == null) {
        if (force || _lastSignature != 'off') await service.cancelAll();
        _lastSignature = 'off';
        _emit(const ReminderStatus(ReminderPhase.off));
        // The user may have allowed notifications in the system settings
        // after a refusal: forget the refusal.
        if (await prefs.permissionRefused() &&
            await service.permissionStatus() ==
                NotificationPermission.granted) {
          await prefs.setPermissionRefused(false);
          if (ref.mounted) ref.invalidate(permissionRefusedProvider);
        }
        return;
      }

      if (await service.permissionStatus() != NotificationPermission.granted) {
        await service.cancelAll();
        _lastSignature = 'blocked';
        _emit(const ReminderStatus(ReminderPhase.permissionMissing));
        return;
      }

      final now = clock.now();
      final answered = (await repository.dailyStat(now)).answered;
      if (!ref.mounted) return;
      var due = 0;
      try {
        due = (await repository.dueQuestions(settings.licence, now)).length;
      } on Object catch (e) {
        debugPrint('Counting due questions for the reminders failed: $e');
      }
      final location = await service.localLocation();
      if (!ref.mounted) return;
      final local = lookupAppLocalizations(
        resolveReminderLocale(deviceLocale()),
      );
      final plan = planReminders(
        reminderTime: settings.reminderTime,
        examDate: settings.examDate,
        dailyGoal: settings.dailyGoal,
        answeredToday: answered,
        dueQuestions: due,
        now: now,
        location: location,
        texts: LocalizedReminderTexts(local),
      );
      final signature = plan
          .map(
            (r) =>
                '${r.id}|${r.at.millisecondsSinceEpoch}|${r.title}|${r.body}',
          )
          .join('\n');
      if (!force &&
          signature == _lastSignature &&
          state.phase == ReminderPhase.scheduled) {
        return;
      }
      final channel = ReminderChannel(
        name: local.reminderChannelName,
        description: local.reminderChannelDescription,
      );
      await service.cancelAll();
      for (final reminder in plan) {
        await service.schedule(reminder, channel);
      }
      _lastSignature = signature;
      _emit(ReminderStatus(ReminderPhase.scheduled, plan.length));
    } on Object catch (e, stack) {
      debugPrint('Scheduling the reminders failed: $e\n$stack');
      _lastSignature = null;
      _emit(const ReminderStatus(ReminderPhase.failed));
    }
  }

  void _emit(ReminderStatus status) {
    if (ref.mounted) state = status;
  }

  /// Asks the system for the notification permission (call only after a tap
  /// of the user) and remembers a refusal.
  Future<NotificationPermission> requestPermission() async {
    final service = ref.read(notificationServiceProvider);
    final prefs = ref.read(reminderPrefsProvider);
    try {
      final result = await service.requestPermission();
      await prefs.setPermissionRefused(
        result != NotificationPermission.granted,
      );
      ref.invalidate(permissionRefusedProvider);
      return result;
    } on Object catch (e) {
      debugPrint('Asking for the notification permission failed: $e');
      return NotificationPermission.denied;
    }
  }

  /// The current permission; asks the system only if it is not granted yet.
  /// Call only after a tap of the user.
  Future<NotificationPermission> ensurePermission() async {
    final service = ref.read(notificationServiceProvider);
    try {
      if (await service.permissionStatus() == NotificationPermission.granted) {
        return NotificationPermission.granted;
      }
    } on Object catch (e) {
      debugPrint('Reading the notification permission failed: $e');
    }
    return requestPermission();
  }

  /// Switches the reminders on at [time]: asks for the permission first and
  /// stores the time only if it was given.
  Future<ReminderEnableResult> enable(ReminderTime time) async {
    if (await ensurePermission() != NotificationPermission.granted) {
      return ReminderEnableResult.permissionDenied;
    }
    try {
      await ref
          .read(userSettingsProvider.notifier)
          .change((s) => s.copyWith(reminderTime: time));
    } on Object catch (e) {
      debugPrint('Saving the reminder time failed: $e');
      return ReminderEnableResult.saveFailed;
    }
    return ReminderEnableResult.enabled;
  }

  /// Switches the reminders off (the schedule is cleared by the settings
  /// listener).
  Future<bool> disable() async {
    try {
      await ref
          .read(userSettingsProvider.notifier)
          .change((s) => s.copyWith(clearReminderTime: true));
      return true;
    } on Object catch (e) {
      debugPrint('Saving the reminder switch failed: $e');
      return false;
    }
  }

  Future<bool> openSystemSettings() async {
    try {
      return await ref.read(notificationServiceProvider).openSystemSettings();
    } on Object {
      return false;
    }
  }
}

final reminderCoordinatorProvider =
    NotifierProvider<ReminderCoordinator, ReminderStatus>(
      ReminderCoordinator.new,
    );
