import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/bank/licence_provider.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/progress/user_settings.dart';

/// PL / EN switch for the language of the questions. When [licence] is given
/// and has no English bank, only a hint is shown; without [licence] the
/// switch is always shown and the hint says where English is available.
class QuestionLanguageSelector extends ConsumerWidget {
  const QuestionLanguageSelector({super.key, this.licence});

  final Licence? licence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    final licence = this.licence;
    final language = ref.watch(questionLanguageProvider);
    final available = licence == null || licence.hasEnglish;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            local.questionLanguageLabel,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          if (available)
            SegmentedButton<QuestionLanguage>(
              key: const Key('question_language'),
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
              onSelectionChanged: (selection) =>
                  selectQuestionLanguage(ref, selection.first).ignore(),
            )
          else
            Text(
              local.questionLanguageEnglishHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}
