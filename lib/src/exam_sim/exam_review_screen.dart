import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/bank/bank_text.dart';
import 'package:pilotiq/src/bank/licence_provider.dart';
import 'package:pilotiq/src/bank/models.dart';
import 'package:pilotiq/src/exam_sim/exam_controller.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/materials/explanation_panel.dart';
import 'package:pilotiq/src/progress/exam_attempt.dart';
import 'package:pilotiq/src/progress/user_settings.dart';

/// Every question of an attempt with the answer that was chosen and the
/// correct one, from the stored canonical indices. A question that is no
/// longer in the bank is shown as a line saying so.
class ExamReviewScreen extends ConsumerStatefulWidget {
  const ExamReviewScreen({
    super.key,
    required this.attempt,
    required this.args,
  });

  final ExamAttempt attempt;
  final ExamArgs args;

  @override
  ConsumerState<ExamReviewScreen> createState() => _ExamReviewScreenState();
}

class _ExamReviewScreenState extends ConsumerState<ExamReviewScreen> {
  bool _onlyWrong = false;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final byId = widget.args.byId;
    final language = ref.watch(
      effectiveQuestionLanguageProvider(widget.attempt.licence),
    );
    final ids = widget.attempt.questionIds;
    final entries = <int>[
      for (var i = 0; i < ids.length; i++)
        if (!_onlyWrong ||
            byId[ids[i]] == null ||
            widget.attempt.answers[ids[i]] != byId[ids[i]]!.correctIndex)
          i,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          local.examReviewTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  key: const Key('review_filter_all'),
                  label: Text(local.examReviewFilterAll),
                  selected: !_onlyWrong,
                  showCheckmark: true,
                  onSelected: (_) => setState(() => _onlyWrong = false),
                ),
                ChoiceChip(
                  key: const Key('review_filter_wrong'),
                  label: Text(local.examReviewFilterWrong),
                  selected: _onlyWrong,
                  showCheckmark: true,
                  onSelected: (_) => setState(() => _onlyWrong = true),
                ),
              ],
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        local.examReviewEmptyWrong,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: entries.length,
                    itemBuilder: (context, n) {
                      final i = entries[n];
                      return _ReviewItem(
                        key: ValueKey('review_$i'),
                        index: i,
                        total: ids.length,
                        question: byId[ids[i]],
                        answer: widget.attempt.answers[ids[i]],
                        flagged: widget.attempt.flagged.contains(ids[i]),
                        requested: language,
                        licence: widget.attempt.licence,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ReviewItem extends StatelessWidget {
  const _ReviewItem({
    super.key,
    required this.index,
    required this.total,
    required this.question,
    required this.answer,
    required this.flagged,
    required this.requested,
    required this.licence,
  });

  final int index;
  final int total;
  final Question? question;
  final int? answer;
  final bool flagged;
  final QuestionLanguage requested;
  final Licence licence;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final q = question;
    final heading = local.examReviewQuestionNumber(index + 1, total);
    if (q == null) {
      return Card(
        child: ListTile(
          title: Text(heading),
          subtitle: Text(local.examReviewMissing),
        ),
      );
    }
    final lang = q.displayLanguage(requested);
    final chosen = answer != null && answer! >= 0 && answer! < q.answers.length
        ? q.answers[answer!].resolve(lang)
        : null;
    final correct = answer == q.correctIndex;
    final (IconData icon, String mark) = answer == null
        ? (Icons.help_outline, local.examReviewMarkUnanswered)
        : correct
        ? (Icons.check_circle, local.examReviewMarkCorrect)
        : (Icons.cancel, local.examReviewMarkWrong);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$heading: $mark',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            if (flagged)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.flag, size: 16),
                    const SizedBox(width: 4),
                    Expanded(child: Text(local.examReviewFlagged)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            BankText(
              q.text.resolve(lang),
              style: theme.textTheme.bodyLarge!.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (requested == QuestionLanguage.en && lang == QuestionLanguage.pl)
              Text(
                local.questionShownAsPublishedNote,
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            Text(local.examReviewYourAnswer, style: theme.textTheme.labelLarge),
            chosen == null ? Text(local.examReviewNoAnswer) : BankText(chosen),
            const SizedBox(height: 8),
            Text(
              local.examReviewCorrectAnswer,
              style: theme.textTheme.labelLarge,
            ),
            BankText(q.answers[q.correctIndex].resolve(lang)),
            QuestionExplanation(
              licence: licence,
              questionId: q.id,
              questionLanguage: lang,
            ),
          ],
        ),
      ),
    );
  }
}
