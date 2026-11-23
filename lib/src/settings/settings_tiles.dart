import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/bank/licence_presentation.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/progress/providers.dart';
import 'package:pilotiq/src/progress/user_settings.dart';

/// Daily goals offered in the settings and in the onboarding.
const List<int> dailyGoalChoices = [10, 20, 40];

/// Applies [mutate] to the stored settings. A failed save leaves the screen
/// consistent (the old value stays) and offers "Retry" in a snack bar.
Future<bool> changeSettings(
  BuildContext context,
  WidgetRef ref,
  UserSettings Function(UserSettings current) mutate,
) async {
  try {
    await ref.read(userSettingsProvider.notifier).change(mutate);
    return true;
  } on Object {
    if (!context.mounted) return false;
    final local = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(local.settingsSaveError),
          action: SnackBarAction(
            label: local.settingsRetry,
            onPressed: () {
              if (!context.mounted) return;
              // A box that failed to open is remembered by the repository,
              // so the retry starts with a fresh one.
              ref.invalidate(progressRepositoryProvider);
              changeSettings(context, ref, mutate).ignore();
            },
          ),
        ),
      );
    return false;
  }
}

/// Section header of the settings list.
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
    child: Semantics(
      header: true,
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    ),
  );
}

/// Slot for the "Reminders" section. The reminders step fills it in.
class RemindersSettingsSlot extends StatelessWidget {
  const RemindersSettingsSlot({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Slot for the purchases section ("Restore purchases"). The paywall step
/// fills it in.
class PurchasesSettingsSlot extends StatelessWidget {
  const PurchasesSettingsSlot({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class LicenceTile extends ConsumerWidget {
  const LicenceTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    final settings = ref.watch(userSettingsProvider).value;
    final licence = settings?.licence ?? Licence.ppla;
    return ListTile(
      key: const Key('settings_licence'),
      leading: const Icon(Icons.flight),
      title: Text(local.settingsLicenceTitle),
      subtitle: Text('${licence.title(local)} · ${licence.subtitle(local)}'),
      onTap: settings == null
          ? null
          : () async {
              final picked = await showDialog<Licence>(
                context: context,
                builder: (context) => SimpleDialog(
                  title: Text(local.settingsLicenceTitle),
                  children: [
                    for (final option in Licence.values)
                      SimpleDialogOption(
                        key: Key('licence_option_${option.id}'),
                        onPressed: () => Navigator.of(context).pop(option),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${option.title(local)} · '
                                '${option.subtitle(local)}',
                              ),
                            ),
                            if (option == licence) const Icon(Icons.check),
                          ],
                        ),
                      ),
                  ],
                ),
              );
              if (picked == null || picked == licence || !context.mounted) {
                return;
              }
              await changeSettings(
                context,
                ref,
                (s) => s.copyWith(licence: picked),
              );
            },
    );
  }
}

class QuestionLanguageTile extends ConsumerWidget {
  const QuestionLanguageTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    final settings = ref.watch(userSettingsProvider).value;
    final licence = settings?.licence ?? Licence.ppla;
    final language = settings?.questionLanguage ?? QuestionLanguage.pl;
    return ListTile(
      leading: const Icon(Icons.translate),
      title: Text(local.questionLanguageLabel),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: licence.hasEnglish
            ? SegmentedButton<QuestionLanguage>(
                key: const Key('settings_question_language'),
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: QuestionLanguage.pl,
                    label: Text(local.questionLanguagePolish),
                  ),
                  ButtonSegment(
                    value: QuestionLanguage.en,
                    label: Text(local.questionLanguageEnglish),
                  ),
                ],
                selected: {language},
                onSelectionChanged: settings == null
                    ? null
                    : (selection) => changeSettings(
                        context,
                        ref,
                        (s) => s.copyWith(questionLanguage: selection.first),
                      ),
              )
            : Text(local.questionLanguageEnglishHint),
      ),
    );
  }
}

class ExamDateTile extends ConsumerWidget {
  const ExamDateTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    final settings = ref.watch(userSettingsProvider).value;
    final date = settings?.examDate;
    return ListTile(
      key: const Key('settings_exam_date'),
      leading: const Icon(Icons.event),
      title: Text(local.settingsExamDateTitle),
      subtitle: Text(
        date == null
            ? local.settingsExamDateNotSet
            : MaterialLocalizations.of(context).formatMediumDate(date),
      ),
      trailing: date == null
          ? null
          : IconButton(
              key: const Key('settings_exam_date_clear'),
              icon: const Icon(Icons.close),
              tooltip: local.settingsExamDateClear,
              onPressed: () => changeSettings(
                context,
                ref,
                (s) => s.copyWith(clearExamDate: true),
              ),
            ),
      onTap: settings == null
          ? null
          : () async {
              final picked = await pickExamDate(context, ref, current: date);
              if (picked == null || !context.mounted) return;
              await changeSettings(
                context,
                ref,
                (s) => s.copyWith(examDate: picked),
              );
            },
    );
  }
}

/// Date picker for the exam date; the result is a local date at midnight.
Future<DateTime?> pickExamDate(
  BuildContext context,
  WidgetRef ref, {
  DateTime? current,
}) async {
  final now = ref.read(clockProvider).now();
  final today = DateTime(now.year, now.month, now.day);
  final initial = current != null && !current.isBefore(today)
      ? current
      : today.add(const Duration(days: 30));
  final picked = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: today,
    lastDate: DateTime(today.year + 3, today.month, today.day),
    helpText: AppLocalizations.of(context)!.settingsExamDateHelp,
  );
  if (picked == null) return null;
  return DateTime(picked.year, picked.month, picked.day);
}

class DailyGoalTile extends ConsumerWidget {
  const DailyGoalTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    final settings = ref.watch(userSettingsProvider).value;
    final goal = settings?.dailyGoal ?? UserSettings.defaultDailyGoal;
    return ListTile(
      key: const Key('settings_daily_goal'),
      leading: const Icon(Icons.flag_outlined),
      title: Text(local.settingsDailyGoalTitle),
      subtitle: Text(local.settingsDailyGoalValue(goal)),
      onTap: settings == null
          ? null
          : () async {
              final choices = {...dailyGoalChoices, goal}.toList()..sort();
              final picked = await showDialog<int>(
                context: context,
                builder: (context) => SimpleDialog(
                  title: Text(local.settingsDailyGoalTitle),
                  children: [
                    for (final option in choices)
                      SimpleDialogOption(
                        key: Key('goal_option_$option'),
                        onPressed: () => Navigator.of(context).pop(option),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(local.settingsDailyGoalValue(option)),
                            ),
                            if (option == goal) const Icon(Icons.check),
                          ],
                        ),
                      ),
                  ],
                ),
              );
              if (picked == null || picked == goal || !context.mounted) return;
              await changeSettings(
                context,
                ref,
                (s) => s.copyWith(dailyGoal: picked),
              );
            },
    );
  }
}

class ThemeTile extends ConsumerWidget {
  const ThemeTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    final settings = ref.watch(userSettingsProvider).value;
    final mode = settings?.themeMode ?? AppThemeMode.system;
    return ListTile(
      leading: const Icon(Icons.brightness_6_outlined),
      title: Text(local.settingsThemeTitle),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: SegmentedButton<AppThemeMode>(
          key: const Key('settings_theme'),
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: AppThemeMode.system,
              label: Text(local.settingsThemeSystem),
            ),
            ButtonSegment(
              value: AppThemeMode.light,
              label: Text(local.settingsThemeLight),
            ),
            ButtonSegment(
              value: AppThemeMode.dark,
              label: Text(local.settingsThemeDark),
            ),
          ],
          selected: {mode},
          onSelectionChanged: settings == null
              ? null
              : (selection) => changeSettings(
                  context,
                  ref,
                  (s) => s.copyWith(themeMode: selection.first),
                ),
        ),
      ),
    );
  }
}
