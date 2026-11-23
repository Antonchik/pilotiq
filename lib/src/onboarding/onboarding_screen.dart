import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/bank/licence_presentation.dart';
import 'package:pilotiq/src/dashboard/dashboard_providers.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/progress/providers.dart';
import 'package:pilotiq/src/progress/user_settings.dart';
import 'package:pilotiq/src/settings/settings_tiles.dart';

/// Choices made during the onboarding. They are written to the settings in
/// one go when the user finishes.
class OnboardingDraft {
  const OnboardingDraft({
    required this.licence,
    required this.language,
    required this.examDate,
    required this.dailyGoal,
    required this.fromLegacy,
  });

  final Licence licence;
  final QuestionLanguage language;
  final DateTime? examDate;
  final int dailyGoal;

  /// Pre-filled from results migrated from version 1.x.
  final bool fromLegacy;

  OnboardingDraft copyWith({
    Licence? licence,
    QuestionLanguage? language,
    DateTime? examDate,
    bool clearExamDate = false,
    int? dailyGoal,
  }) => OnboardingDraft(
    licence: licence ?? this.licence,
    language: language ?? this.language,
    examDate: clearExamDate ? null : (examDate ?? this.examDate),
    dailyGoal: dailyGoal ?? this.dailyGoal,
    fromLegacy: fromLegacy,
  );
}

class OnboardingDraftNotifier extends Notifier<OnboardingDraft> {
  @override
  OnboardingDraft build() {
    final settings =
        ref.read(userSettingsProvider).value ?? const UserSettings();
    final hint = ref.read(legacyLicenceHintProvider).value;
    return OnboardingDraft(
      licence: hint ?? settings.licence,
      language: settings.questionLanguage,
      examDate: settings.examDate,
      dailyGoal: settings.dailyGoal,
      fromLegacy: hint != null,
    );
  }

  void update(OnboardingDraft Function(OnboardingDraft) change) =>
      state = change(state);
}

final onboardingDraftProvider =
    NotifierProvider.autoDispose<OnboardingDraftNotifier, OnboardingDraft>(
      OnboardingDraftNotifier.new,
    );

/// One page of the onboarding. Further pages (reminders) are added to
/// [onboardingStepsProvider].
class OnboardingStep {
  const OnboardingStep({
    required this.id,
    required this.builder,
    this.skippable = false,
  });

  final String id;
  final WidgetBuilder builder;

  /// A skippable page shows "Skip" next to "Next".
  final bool skippable;
}

/// The pages of the onboarding, in order.
final onboardingStepsProvider = Provider<List<OnboardingStep>>(
  (ref) => [
    OnboardingStep(id: 'licence', builder: (context) => const _LicenceStep()),
    OnboardingStep(
      id: 'examDate',
      skippable: true,
      builder: (context) => const _ExamDateStep(),
    ),
    OnboardingStep(id: 'goal', builder: (context) => const _GoalStep()),
  ],
);

/// First-launch flow. Users coming from version 1.x get the licence of their
/// results pre-selected.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _index = 0;
  bool _saving = false;

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    final draft = ref.read(onboardingDraftProvider);
    final saved = await changeSettings(
      context,
      ref,
      (s) => s.copyWith(
        licence: draft.licence,
        questionLanguage: draft.language,
        examDate: draft.examDate,
        clearExamDate: draft.examDate == null,
        dailyGoal: draft.dailyGoal,
        onboardingDone: true,
      ),
    );
    if (!saved && mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    // Wait for the legacy hint so that the pre-selection is right from the
    // first frame.
    final hint = ref.watch(legacyLicenceHintProvider);
    if (hint.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final steps = ref.watch(onboardingStepsProvider);
    final step = steps[_index];
    final isLast = _index == steps.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(value: (_index + 1) / steps.length),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  local.onboardingStepOf(_index + 1, steps.length),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: KeyedSubtree(
                  key: ValueKey(step.id),
                  child: step.builder(context),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_index > 0)
                    TextButton(
                      key: const Key('onboarding_back'),
                      onPressed: _saving
                          ? null
                          : () => setState(() => _index--),
                      child: Text(local.onboardingBack),
                    ),
                  const Spacer(),
                  if (step.skippable && !isLast)
                    TextButton(
                      key: const Key('onboarding_skip'),
                      onPressed: () {
                        if (step.id == 'examDate') {
                          ref
                              .read(onboardingDraftProvider.notifier)
                              .update((d) => d.copyWith(clearExamDate: true));
                        }
                        setState(() => _index++);
                      },
                      child: Text(local.onboardingSkip),
                    ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: Key(isLast ? 'onboarding_finish' : 'onboarding_next'),
                    onPressed: _saving
                        ? null
                        : isLast
                        ? _finish
                        : () => setState(() => _index++),
                    child: Text(
                      isLast ? local.onboardingFinish : local.onboardingNext,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        header: true,
        child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
      ),
      const SizedBox(height: 8),
      Text(body),
      const SizedBox(height: 16),
    ],
  );
}

class _LicenceStep extends ConsumerWidget {
  const _LicenceStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    final draft = ref.watch(onboardingDraftProvider);
    final notifier = ref.read(onboardingDraftProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepTitle(
          title: local.onboardingWelcomeTitle,
          body: local.onboardingWelcomeBody,
        ),
        if (draft.fromLegacy)
          Card(
            key: const Key('onboarding_legacy_banner'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.history),
                  const SizedBox(width: 12),
                  Expanded(child: Text(local.onboardingLegacyBanner)),
                ],
              ),
            ),
          ),
        for (final licence in Licence.values)
          Card(
            key: Key('onboarding_licence_${licence.id}'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: licence == draft.licence
                  ? BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    )
                  : BorderSide.none,
            ),
            child: ListTile(
              selected: licence == draft.licence,
              title: Text(licence.title(local)),
              subtitle: Text(licence.subtitle(local)),
              trailing: licence == draft.licence
                  ? const Icon(Icons.check_circle)
                  : null,
              onTap: () => notifier.update((d) => d.copyWith(licence: licence)),
            ),
          ),
        const SizedBox(height: 12),
        Text(
          local.questionLanguageLabel,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        if (draft.licence.hasEnglish)
          SegmentedButton<QuestionLanguage>(
            key: const Key('onboarding_language'),
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
            selected: {draft.language},
            onSelectionChanged: (s) =>
                notifier.update((d) => d.copyWith(language: s.first)),
          )
        else
          Text(local.questionLanguageEnglishHint),
      ],
    );
  }
}

class _ExamDateStep extends ConsumerWidget {
  const _ExamDateStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    final draft = ref.watch(onboardingDraftProvider);
    final date = draft.examDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepTitle(
          title: local.onboardingExamDateTitle,
          body: local.onboardingExamDateBody,
        ),
        ListTile(
          key: const Key('onboarding_exam_date'),
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
                  icon: const Icon(Icons.close),
                  tooltip: local.settingsExamDateClear,
                  onPressed: () => ref
                      .read(onboardingDraftProvider.notifier)
                      .update((d) => d.copyWith(clearExamDate: true)),
                ),
          onTap: () async {
            final picked = await pickExamDate(context, ref, current: date);
            if (picked == null) return;
            ref
                .read(onboardingDraftProvider.notifier)
                .update((d) => d.copyWith(examDate: picked));
          },
        ),
      ],
    );
  }
}

class _GoalStep extends ConsumerWidget {
  const _GoalStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    final draft = ref.watch(onboardingDraftProvider);
    final choices = {...dailyGoalChoices, draft.dailyGoal}.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepTitle(
          title: local.onboardingGoalTitle,
          body: local.onboardingGoalBody,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final goal in choices)
              ChoiceChip(
                key: Key('onboarding_goal_$goal'),
                label: Text(local.settingsDailyGoalValue(goal)),
                selected: goal == draft.dailyGoal,
                onSelected: (_) => ref
                    .read(onboardingDraftProvider.notifier)
                    .update((d) => d.copyWith(dailyGoal: goal)),
              ),
          ],
        ),
      ],
    );
  }
}
