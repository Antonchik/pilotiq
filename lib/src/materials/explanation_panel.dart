import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/materials/materials_disclaimer.dart';
import 'package:pilotiq/src/materials/materials_providers.dart';
import 'package:pilotiq/src/materials/report_error.dart';
import 'package:pilotiq/src/progress/user_settings.dart';
import 'package:pilotiq/src/purchases/paywall_launcher.dart';

/// The explanation of a question, if it has one: an [ExplanationPanel] once
/// the materials are loaded, nothing while loading or when there is none.
/// Watching it is what loads the materials of the subject (lazily).
class QuestionExplanation extends ConsumerWidget {
  const QuestionExplanation({
    super.key,
    required this.licence,
    required this.questionId,
    required this.questionLanguage,
  });

  final Licence licence;
  final String questionId;

  /// Language the question is shown in; English adds the "Polish only" note.
  final QuestionLanguage questionLanguage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref
        .watch(explanationForQuestionProvider((licence, questionId)))
        .value;
    if (view == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ExplanationPanel(
        view: view,
        polishOnly: questionLanguage == QuestionLanguage.en,
      ),
    );
  }
}

/// Explanation shown after an answer in practice and under the questions of
/// an exam review: the text, its sources, the "disputed" block, the
/// disclaimer and "report an error". A locked explanation shows only a
/// teaser with the button that opens the paywall.
class ExplanationPanel extends StatelessWidget {
  const ExplanationPanel({
    super.key,
    required this.view,
    this.polishOnly = false,
  });

  final ExplanationView view;
  final bool polishOnly;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final note = view.disputeNote;
    return Container(
      key: const Key('explanation_panel'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (view.outdated) _OutdatedBlock(note: view.outdatedNote),
          if (view.hasExplanation) ...[
            Semantics(
              header: true,
              child: Row(
                children: [
                  Icon(
                    view.locked ? Icons.lock_outline : Icons.menu_book_outlined,
                    size: 20,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      view.locked
                          ? local.explanationLockedTitle
                          : local.explanationTitle,
                      key: const Key('explanation_title'),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
            ),
            if (polishOnly)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  local.explanationPolishOnly,
                  key: const Key('explanation_polish_only'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 8),
          ] else if (polishOnly && view.outdatedNote != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                local.explanationPolishOnly,
                key: const Key('explanation_polish_only'),
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (view.locked) ...[
            if (view.disputed) const _DisputedBlock(),
            if (!view.hasExplanation)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  local.materialsOutdatedLocked,
                  key: const Key('explanation_outdated_locked'),
                ),
              ),
            FilledButton.tonal(
              key: const Key('explanation_unlock'),
              onPressed: () => openPaywall(
                context,
                trigger: PaywallTrigger.materials,
                explicit: true,
              ),
              child: Text(local.materialsUnlock),
            ),
          ] else ...[
            if (view.disputed) _DisputedBlock(note: note),
            if (view.hasExplanation)
              Text(
                view.text,
                key: const Key('explanation_text'),
                style: theme.textTheme.bodyMedium,
              ),
            if (view.refs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  local.materialsSources(view.refs.join('; ')),
                  key: const Key('explanation_refs'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const SizedBox(height: 6),
            const MaterialsDisclaimer(compact: true),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const Key('explanation_report'),
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: Text(local.materialsReportError),
                onPressed: () => reportMaterialError(
                  context,
                  MaterialReport(
                    materialKey: view.key,
                    questionId: view.questionId,
                    licence: view.licence,
                    materialsVersion: view.materialsVersion,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Pytanie sporne": the ULC key is doubtful, but it is the one that counts
/// in the exam. [note] (why it is doubtful) is Premium content: a locked
/// explanation shows the block without it.
class _DisputedBlock extends StatelessWidget {
  const _DisputedBlock({this.note});

  final String? note;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final note = this.note;
    return Container(
      key: const Key('explanation_disputed'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              local.materialsDisputedTitle,
              key: const Key('explanation_disputed_title'),
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.onTertiaryContainer,
              ),
            ),
          ),
          if (note != null)
            Text(
              note,
              key: const Key('explanation_dispute_note'),
              style: TextStyle(color: scheme.onTertiaryContainer),
            ),
          Text(
            local.materialsDisputedExam,
            key: const Key('explanation_disputed_exam'),
            style: TextStyle(
              color: scheme.onTertiaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Nieaktualne przepisy": the question is based on repealed norms; the ULC
/// key still counts in the exam. Shown to every user; [note] (what changed)
/// is Premium content and is null for a free user.
class _OutdatedBlock extends StatelessWidget {
  const _OutdatedBlock({this.note});

  final String? note;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final note = this.note;
    final color = scheme.onSecondaryContainer;
    return Container(
      key: const Key('explanation_outdated'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_edu_outlined, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    local.materialsOutdatedTitle,
                    key: const Key('explanation_outdated_title'),
                    style: theme.textTheme.titleSmall?.copyWith(color: color),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            local.materialsOutdatedBody,
            key: const Key('explanation_outdated_body'),
            style: TextStyle(color: color),
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                note,
                key: const Key('explanation_outdated_note'),
                style: TextStyle(color: color, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }
}
