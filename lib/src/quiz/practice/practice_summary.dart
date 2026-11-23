import 'package:flutter/material.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';

/// End-of-session summary: counts of right and wrong answers, a way to repeat
/// the mistakes of the session and a way back to the subject.
class PracticeSummary extends StatelessWidget {
  const PracticeSummary({
    super.key,
    required this.correct,
    required this.wrong,
    required this.onRepeatMistakes,
    required this.onBack,
  });

  final int correct;
  final int wrong;

  /// `null` when there is nothing to repeat.
  final VoidCallback? onRepeatMistakes;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final answered = correct + wrong;
    final percent = answered == 0 ? 0 : (100 * correct / answered).round();
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              local.practiceSummaryTitle,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (answered == 0)
              Text(local.practiceSummaryNothing, textAlign: TextAlign.center)
            else ...[
              Text(
                local.practiceSummaryCorrect(correct),
                key: const Key('summary_correct'),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              Text(
                local.practiceSummaryWrong(wrong),
                key: const Key('summary_wrong'),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                local.practiceSummaryAccuracy(percent),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            if (onRepeatMistakes != null)
              FilledButton.icon(
                key: const Key('summary_repeat'),
                icon: const Icon(Icons.replay),
                label: Text(local.practiceRepeatMistakes),
                onPressed: onRepeatMistakes,
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('summary_back'),
              icon: const Icon(Icons.arrow_back),
              label: Text(local.returnToSubjectTitle),
              onPressed: onBack,
            ),
          ],
        ),
      ),
    );
  }
}
