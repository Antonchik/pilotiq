import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/exam_sim/exam_entry.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/purchases/paywall_launcher.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';
import 'package:pilotiq/src/quiz/practice/practice_controller.dart';
import 'package:pilotiq/src/quiz/practice/practice_screen.dart';
import 'package:pilotiq/src/quiz/practice/practice_session.dart';
import 'package:pilotiq/src/subjects/subject_info.dart';

/// Study modes of a subject with live counters. Mistakes and review need
/// Premium: for a free user the tile shows the counter and opens the paywall.
class QuizList extends ConsumerWidget {
  final SubjectInfo subject;

  const QuizList({super.key, required this.subject});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    final isPremium = ref.watch(isPremiumProvider);
    final key = (licence: subject.licence, subject: subject.id);
    final stats = ref.watch(subjectStatsProvider(key)).value;

    Future<void> practise(PracticeMode mode) async {
      await openPractice(
        context,
        PracticeArgs(
          licence: subject.licence,
          subject: subject.id,
          mode: mode,
          questions: subject.questions,
        ),
      );
      ref.invalidate(subjectStatsProvider(key));
    }

    Widget modeTile({
      required Key tileKey,
      required PracticeMode mode,
      required String title,
      required String description,
      required String? status,
    }) {
      final locked = practiceModeLocked(mode, isPremium);
      return _ModeTile(
        key: tileKey,
        title: title,
        description: description,
        status: status,
        lockedBadge: locked ? local.practiceLockedBadge : null,
        onTap: locked
            ? () => openPaywall(context, trigger: PaywallTrigger.lockedFeature)
            : () => practise(mode),
      );
    }

    return Column(
      children: [
        modeTile(
          tileKey: const Key('mode_learn'),
          mode: PracticeMode.learn,
          title: local.fullQuizTitle,
          description: local.fullModeDescription,
          status: stats == null
              ? null
              : local.practiceModeLearnStatus(stats.unseen),
        ),
        _ModeTile(
          key: const Key('mode_exam'),
          title: local.examQuizTitle,
          description: local.examModeDescription,
          onTap: () => openExamSimulation(context, ref, subject),
        ),
        modeTile(
          tileKey: const Key('mode_mistakes'),
          mode: PracticeMode.mistakes,
          title: local.subjectModeMistakesTitle,
          description: local.subjectModeMistakesDescription,
          status: stats == null
              ? null
              : local.practiceModeMistakesStatus(stats.mistakes),
        ),
        modeTile(
          tileKey: const Key('mode_review'),
          mode: PracticeMode.review,
          title: local.subjectModeReviewTitle,
          description: local.subjectModeReviewDescription,
          status: stats == null
              ? null
              : local.practiceModeReviewStatus(stats.due),
        ),
        modeTile(
          tileKey: const Key('mode_bookmarks'),
          mode: PracticeMode.bookmarks,
          title: local.subjectModeBookmarksTitle,
          description: local.subjectModeBookmarksDescription,
          status: stats == null
              ? null
              : local.practiceModeBookmarksStatus(stats.bookmarks),
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
    this.status,
    this.lockedBadge,
  });

  final String title;
  final String description;
  final VoidCallback? onTap;

  /// Live counter shown under the description.
  final String? status;

  /// Badge text of a mode that is not available yet (the tile is disabled).
  final String? soonBadge;

  /// Badge of a Premium mode that the user cannot use yet (the tile still
  /// reacts to a tap by opening the paywall).
  final String? lockedBadge;

  @override
  Widget build(BuildContext context) {
    final badge = soonBadge ?? lockedBadge;
    final stat = status;
    return Semantics(
      container: true,
      button: onTap != null,
      enabled: onTap != null,
      onTap: onTap,
      label: [title, description, ?stat, ?badge].join('. '),
      excludeSemantics: true,
      child: Card(
        margin: const EdgeInsets.all(4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: ListTile(
          enabled: onTap != null,
          title: Text(title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(description, textAlign: TextAlign.justify),
              if (stat != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    stat,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
            ],
          ),
          trailing: badge == null
              ? null
              : Chip(
                  avatar: lockedBadge == null
                      ? null
                      : const Icon(Icons.lock_outline, size: 16),
                  label: Text(badge),
                ),
          onTap: onTap,
        ),
      ),
    );
  }
}
