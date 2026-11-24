import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/notifications/notification_service.dart';
import 'package:pilotiq/src/notifications/providers.dart';
import 'package:pilotiq/src/notifications/reminder_settings_tile.dart';
import 'package:pilotiq/src/onboarding/onboarding_screen.dart';

/// Onboarding page "When should we remind you?". The system permission is
/// requested only when the user taps "Turn on reminders"; a refusal does not
/// block the onboarding and is remembered.
class ReminderOnboardingPage extends ConsumerStatefulWidget {
  const ReminderOnboardingPage({super.key});

  @override
  ConsumerState<ReminderOnboardingPage> createState() =>
      _ReminderOnboardingPageState();
}

class _ReminderOnboardingPageState
    extends ConsumerState<ReminderOnboardingPage> {
  bool _busy = false;

  Future<void> _enable() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await ref
        .read(reminderCoordinatorProvider.notifier)
        .ensurePermission();
    if (!mounted) return;
    ref
        .read(onboardingDraftProvider.notifier)
        .update(
          (d) => result == NotificationPermission.granted
              ? d.copyWith(reminderTime: d.reminderTime ?? defaultReminderTime)
              : d.copyWith(clearReminderTime: true),
        );
    setState(() => _busy = false);
  }

  Future<void> _changeTime() async {
    final current = ref.read(onboardingDraftProvider).reminderTime;
    final picked = await pickReminderTime(context, current: current);
    if (picked == null || !mounted) return;
    ref
        .read(onboardingDraftProvider.notifier)
        .update((d) => d.copyWith(reminderTime: picked));
  }

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final time = ref.watch(onboardingDraftProvider).reminderTime;
    final refused = ref.watch(permissionRefusedProvider).value ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            local.onboardingRemindersTitle,
            style: theme.textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 8),
        Text(local.onboardingRemindersBody),
        const SizedBox(height: 16),
        if (time == null) ...[
          FilledButton.icon(
            key: const Key('onboarding_reminders_enable'),
            icon: const Icon(Icons.notifications_active_outlined),
            label: Text(local.onboardingRemindersEnable),
            onPressed: _busy ? null : _enable,
          ),
          if (refused) ...[
            const SizedBox(height: 12),
            Text(
              local.onboardingRemindersDenied,
              key: const Key('onboarding_reminders_denied'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
            TextButton.icon(
              key: const Key('onboarding_reminders_open_settings'),
              icon: const Icon(Icons.settings_outlined),
              label: Text(local.remindersOpenSettings),
              onPressed: () => openNotificationSettings(context, ref),
            ),
          ],
        ] else ...[
          Text(
            local.onboardingRemindersEnabled(formatReminderTime(context, time)),
            key: const Key('onboarding_reminders_enabled'),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Tooltip(
              message: local.remindersTimeTitle,
              child: OutlinedButton.icon(
                key: const Key('onboarding_reminder_time'),
                icon: const Icon(Icons.schedule),
                label: Text(formatReminderTime(context, time)),
                onPressed: _changeTime,
              ),
            ),
          ),
          TextButton(
            key: const Key('onboarding_reminders_off'),
            onPressed: () => ref
                .read(onboardingDraftProvider.notifier)
                .update((d) => d.copyWith(clearReminderTime: true)),
            child: Text(local.remindersToggleOff),
          ),
        ],
      ],
    );
  }
}
