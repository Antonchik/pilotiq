import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/domain/access_policy.dart';
import 'package:pilotiq/src/domain/exam_scoring.dart';
import 'package:pilotiq/src/exam_sim/exam_controller.dart';
import 'package:pilotiq/src/exam_sim/exam_entry.dart';
import 'package:pilotiq/src/exam_sim/exam_format.dart';
import 'package:pilotiq/src/exam_sim/exam_review_screen.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/progress/exam_attempt.dart';
import 'package:pilotiq/src/purchases/paywall_launcher.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';
import 'package:pilotiq/src/quiz/practice/practice_controller.dart';
import 'package:pilotiq/src/quiz/practice/practice_screen.dart';
import 'package:pilotiq/src/quiz/practice/practice_session.dart';

/// Result of a stored attempt. Everybody sees the outcome and the overall
/// score; the breakdown by topic, the review and the training of the mistakes
/// need Premium (a teaser opens the paywall).
class ExamResultsScreen extends ConsumerWidget {
  const ExamResultsScreen({
    super.key,
    required this.attempt,
    required this.args,
    this.notice = ExamNotice.none,
    this.onRepeat,
  });

  final ExamAttempt attempt;
  final ExamArgs args;
  final ExamNotice notice;

  /// `null` hides the "Repeat exam" button.
  final VoidCallback? onRepeat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final premium = ref.watch(isPremiumProvider);
    final detail = AccessPolicy.canUseExamBreakdown(premium);
    final byId = args.byId;
    final percent = (attempt.ratio * 100).round();
    final unanswered = [
      for (final id in attempt.questionIds)
        if (byId.containsKey(id) && attempt.answers[id] == null) id,
    ].length;
    final wrongIds = [
      for (final id in attempt.questionIds)
        if (byId.containsKey(id) &&
            attempt.answers[id] != byId[id]!.correctIndex)
          id,
    ];
    final topics = attempt.topicBreakdown.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final noteText = switch (notice) {
      ExamNotice.timeUp => local.examTimeUpNotice,
      ExamNotice.expiredWhileClosed => local.examExpiredOnOpenNotice,
      ExamNotice.none => null,
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(
          local.examResultTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (noteText != null)
            Semantics(
              liveRegion: true,
              container: true,
              child: Card(
                key: const Key('exam_result_notice'),
                color: theme.colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.timer_off_outlined),
                      const SizedBox(width: 12),
                      Expanded(child: Text(noteText)),
                    ],
                  ),
                ),
              ),
            ),
          Center(child: PassBadge(passed: attempt.passed, large: true)),
          const SizedBox(height: 8),
          Text(
            '$percent%',
            key: const Key('exam_result_percent'),
            textAlign: TextAlign.center,
            style: theme.textTheme.displayMedium,
          ),
          Text(
            local.examResultCorrect(attempt.correct, attempt.total),
            key: const Key('exam_result_score'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            local.examResultPassMark(args.passPercent),
            textAlign: TextAlign.center,
          ),
          Text(
            local.examResultTime(
              formatClock(Duration(seconds: attempt.durationSec)),
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            local.examResultUnanswered(unanswered),
            key: const Key('exam_result_unanswered'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (detail && topics.isNotEmpty) ...[
            Text(local.examBreakdownTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final t in topics) _TopicRow(topic: t.key, score: t.value),
            const SizedBox(height: 8),
          ] else if (!detail)
            Card(
              key: const Key('exam_result_teaser'),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lock_outline),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            local.examTeaserTitle,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(local.examTeaserBody),
                    const SizedBox(height: 8),
                    FilledButton(
                      key: const Key('exam_teaser_premium'),
                      onPressed: () => openPaywall(
                        context,
                        trigger: PaywallTrigger.examResults,
                      ),
                      child: Text(local.goPremiumLabel),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          if (detail) ...[
            FilledButton.icon(
              key: const Key('exam_review'),
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(local.examReviewButton),
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      ExamReviewScreen(attempt: attempt, args: args),
                ),
              ),
            ),
            if (wrongIds.isNotEmpty) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('exam_train'),
                icon: const Icon(Icons.replay),
                label: Text(local.examTrainMistakes),
                onPressed: () => openPractice(
                  context,
                  PracticeArgs(
                    licence: args.licence,
                    subject: args.subject,
                    mode: PracticeMode.retry,
                    questions: args.questions,
                    retryIds: wrongIds,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
          if (onRepeat != null) ...[
            OutlinedButton.icon(
              key: const Key('exam_repeat'),
              icon: const Icon(Icons.refresh),
              label: Text(local.examRepeat),
              onPressed: onRepeat,
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            key: const Key('exam_result_history'),
            icon: const Icon(Icons.history),
            label: Text(local.examHistoryButton),
            onPressed: () => openExamHistory(context, args),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('exam_result_back'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(local.returnToSubjectTitle),
          ),
        ],
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.topic, required this.score});

  final String topic;
  final TopicScore score;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final total = score.total;
    final correct = score.correct;
    final percent = total == 0 ? 0 : (100 * correct / total).round();
    final label = local.examBreakdownRow(topic, correct, total, percent);
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: total == 0 ? 0 : correct / total,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ),
      ),
    );
  }
}
