import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/notifications/providers.dart';
import 'package:pilotiq/src/progress/providers.dart';
import 'package:pilotiq/src/progress/user_settings.dart';

/// Formats [time] the way the device shows times (12 or 24 hours).
String formatReminderTime(BuildContext context, ReminderTime time) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: time.hour, minute: time.minute),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

/// Standard time picker for the reminder time; null when dismissed.
Future<ReminderTime?> pickReminderTime(
  BuildContext context, {
  ReminderTime? current,
}) async {
  final initial = current ?? defaultReminderTime;
  final picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
    helpText: AppLocalizations.of(context)!.remindersTimeTitle,
  );
  if (picked == null) return null;
  return ReminderTime(picked.hour, picked.minute);
}

/// Shows the system settings button's failure as a snack bar.
Future<void> openNotificationSettings(
  BuildContext context,
  WidgetRef ref,
) async {
  final opened = await ref
      .read(reminderCoordinatorProvider.notifier)
      .openSystemSettings();
  if (opened || !context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.remindersOpenSettingsFailed,
        ),
      ),
    );
}

/// Body of the "Reminders" section of the settings (the header is added by
/// the slot): the switch, the time and the state of
/// the permission and of the schedule.
class ReminderSettingsSection extends ConsumerWidget {
  const ReminderSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    final settings = ref.watch(userSettingsProvider).value;
    final status = ref.watch(reminderCoordinatorProvider);
    final refused = ref.watch(permissionRefusedProvider).value ?? false;
    final time = settings?.reminderTime;
    final enabled = time != null;
    final blocked =
        (enabled && status.phase == ReminderPhase.permissionMissing) ||
        (!enabled && refused);
    final failed = enabled && status.phase == ReminderPhase.failed;
    final coordinator = ref.read(reminderCoordinatorProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    Future<void> toggle(bool on) async {
      if (on) {
        final result = await coordinator.enable(defaultReminderTime);
        if (result == ReminderEnableResult.saveFailed && context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(local.settingsSaveError)));
        }
      } else {
        await coordinator.disable();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          key: const Key('settings_reminders_switch'),
          secondary: const Icon(Icons.notifications_active_outlined),
          title: Text(local.remindersToggleTitle),
          subtitle: Text(
            enabled
                ? local.remindersToggleOn(formatReminderTime(context, time))
                : local.remindersToggleOff,
          ),
          value: enabled,
          onChanged: settings == null ? null : toggle,
        ),
        if (enabled)
          ListTile(
            key: const Key('settings_reminder_time'),
            leading: const Icon(Icons.schedule),
            title: Text(local.remindersTimeTitle),
            subtitle: Text(formatReminderTime(context, time)),
            onTap: () async {
              final picked = await pickReminderTime(context, current: time);
              if (picked == null || picked == time) return;
              await coordinator.enable(picked);
            },
          ),
        if (blocked)
          Padding(
            key: const Key('settings_reminders_blocked'),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  local.remindersBlocked,
                  style: TextStyle(color: scheme.error),
                ),
                TextButton.icon(
                  key: const Key('settings_reminders_open_settings'),
                  icon: const Icon(Icons.settings_outlined),
                  label: Text(local.remindersOpenSettings),
                  onPressed: () => openNotificationSettings(context, ref),
                ),
              ],
            ),
          ),
        if (failed)
          Padding(
            key: const Key('settings_reminders_failed'),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  local.remindersScheduleFailed,
                  style: TextStyle(color: scheme.error),
                ),
                TextButton(
                  key: const Key('settings_reminders_retry'),
                  onPressed: () => coordinator.reschedule(force: true),
                  child: Text(local.remindersRetry),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
