import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/exam_sim/exam_entry.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/purchases/paywall_launcher.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';
import 'package:pilotiq/src/quiz/quiz.dart';
import 'package:pilotiq/src/quiz/quiz_config.dart';
import 'package:pilotiq/src/subjects/subject_info.dart';

/// Study modes of a subject. "Learn all" and the exam simulation work; the
/// other tiles are placeholders that the learning steps fill in.
class QuizList extends ConsumerWidget {
  final SubjectInfo subject;

  const QuizList({super.key, required this.subject});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    final isPremium = ref.watch(isPremiumProvider);
    return Column(
      children: [
        _ModeTile(
          key: const Key('mode_learn'),
          title: local.fullQuizTitle,
          description: local.fullModeDescription,
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => QuizScreen(
                quiz: Quiz(
                  type: QuizType.all,
                  title: local.fullQuizTitle,
                  description: local.fullModeDescription,
                  licence: subject.licence,
                  subject: subject.id,
                  questions: subject.questions,
                  spec: subject.spec,
                ),
              ),
            ),
          ),
        ),
        _ModeTile(
          key: const Key('mode_exam'),
          title: local.examQuizTitle,
          description: local.examModeDescription,
          onTap: () => openExamSimulation(context, ref, subject),
        ),
        _ModeTile(
          title: local.subjectModeMistakesTitle,
          description: local.subjectModeMistakesDescription,
          soonBadge: local.subjectModeSoonBadge,
        ),
        _ModeTile(
          title: local.subjectModeReviewTitle,
          description: local.subjectModeReviewDescription,
          soonBadge: local.subjectModeSoonBadge,
        ),
        _ModeTile(
          title: local.subjectModeBookmarksTitle,
          description: local.subjectModeBookmarksDescription,
          soonBadge: local.subjectModeSoonBadge,
        ),
        _ModeTile(
          title: local.subjectModeHistoryTitle,
          description: local.subjectModeHistoryDescription,
          soonBadge: local.subjectModeSoonBadge,
        ),
        if (!isPremium)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () =>
                  openPaywall(context, trigger: PaywallTrigger.lockedFeature),
              child: Text(local.goPremiumLabel),
            ),
          ),
      ],
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    super.key,
    required this.title,
    required this.description,
    this.onTap,
    this.soonBadge,
  });

  final String title;
  final String description;
  final VoidCallback? onTap;

  /// Badge text of a mode that is not available yet (the tile is disabled).
  final String? soonBadge;

  @override
  Widget build(BuildContext context) {
    final badge = soonBadge;
    return Semantics(
      container: true,
      child: Card(
        margin: const EdgeInsets.all(4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: ListTile(
          enabled: onTap != null,
          title: Text(title),
          subtitle: Text(description, textAlign: TextAlign.justify),
          trailing: badge == null ? null : Chip(label: Text(badge)),
          onTap: onTap,
        ),
      ),
    );
  }
}
