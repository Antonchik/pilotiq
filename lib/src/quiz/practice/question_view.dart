import 'package:flutter/material.dart';
import 'package:pilotiq/src/bank/bank_text.dart';
import 'package:pilotiq/src/bank/models.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/progress/user_settings.dart';
import 'package:pilotiq/src/quiz/practice/answer_tile.dart';

/// A question with its answers, drawn from the data it is given. It owns no
/// state and writes nothing: taps are reported through [onAnswer].
class QuestionView extends StatelessWidget {
  const QuestionView({
    super.key,
    required this.question,
    required this.shuffled,
    required this.requestedLanguage,
    required this.selectedCanonical,
    required this.onAnswer,
  });

  final Question question;
  final ShuffledAnswers shuffled;
  final QuestionLanguage requestedLanguage;

  /// Canonical index of the chosen answer; `null` while unanswered.
  final int? selectedCanonical;

  /// Called with the position of the tapped answer on the screen.
  final ValueChanged<int> onAnswer;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final language = question.displayLanguage(requestedLanguage);
    final fellBack =
        requestedLanguage == QuestionLanguage.en &&
        language == QuestionLanguage.pl;
    final answered = selectedCanonical != null;
    final correct = selectedCanonical == question.correctIndex;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        BankText(
          question.text.resolve(language),
          style: theme.textTheme.bodyLarge!.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (fellBack)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              local.questionShownAsPublishedNote,
              style: theme.textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 16),
        for (var position = 0; position < shuffled.length; position++)
          AnswerTile(
            key: ValueKey('answer_$position'),
            text: question.answers[shuffled.canonicalIndexAt(position)].resolve(
              language,
            ),
            state: !answered
                ? AnswerTileState.idle
                : shuffled.canonicalIndexAt(position) == question.correctIndex
                ? AnswerTileState.correct
                : shuffled.canonicalIndexAt(position) == selectedCanonical
                ? AnswerTileState.wrong
                : AnswerTileState.idle,
            onTap: answered ? null : () => onAnswer(position),
          ),
        if (answered)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                correct
                    ? local.practiceFeedbackCorrect
                    : local.practiceFeedbackWrong,
                key: const Key('practice_feedback'),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: feedbackColor(context, correct: correct),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
