import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/domain/access_policy.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/purchases/paywall_launcher.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';
import 'package:pilotiq/src/quiz/practice/practice_controller.dart';
import 'package:pilotiq/src/quiz/practice/practice_session.dart';
import 'package:pilotiq/src/quiz/practice/practice_summary.dart';
import 'package:pilotiq/src/quiz/practice/question_view.dart';

/// Whether [mode] needs Premium for the current user.
bool practiceModeLocked(PracticeMode mode, bool isPremium) => switch (mode) {
  PracticeMode.mistakes => !AccessPolicy.canUseMistakes(isPremium),
  PracticeMode.review => !AccessPolicy.canUseReview(isPremium),
  _ => false,
};

String practiceModeTitle(AppLocalizations local, PracticeMode mode) =>
    switch (mode) {
      PracticeMode.learn => local.fullQuizTitle,
      PracticeMode.review => local.subjectModeReviewTitle,
      PracticeMode.mistakes => local.subjectModeMistakesTitle,
      PracticeMode.bookmarks => local.subjectModeBookmarksTitle,
      PracticeMode.retry => local.practiceRetryTitle,
    };

/// Opens a practice session of [args] as a new screen. Completes when the
/// user comes back, so that the caller can refresh its counters.
Future<void> openPractice(BuildContext context, PracticeArgs args) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => PracticeScreen(args: args)),
    );

/// A practice session (learn, review, mistakes, bookmarks). The session state
/// belongs to this screen only: it is created in a nested [ProviderScope].
class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({super.key, required this.args});

  final PracticeArgs args;

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  late final _overrides = [
    practiceControllerProvider.overrideWith(
      () => PracticeController(widget.args),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(isPremiumProvider);
    if (practiceModeLocked(widget.args.mode, isPremium)) {
      return _LockedScreen(mode: widget.args.mode);
    }
    return ProviderScope(
      overrides: _overrides,
      child: _PracticeBody(args: widget.args),
    );
  }
}

class _LockedScreen extends StatelessWidget {
  const _LockedScreen({required this.mode});

  final PracticeMode mode;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(practiceModeTitle(local, mode))),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 12),
              Text(
                local.practiceLockedTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(local.practiceLockedBody, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    openPaywall(context, trigger: PaywallTrigger.lockedFeature),
                child: Text(local.goPremiumLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PracticeBody extends ConsumerWidget {
  const _PracticeBody({required this.args});

  final PracticeArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    final controller = ref.read(practiceControllerProvider.notifier);
    final async = ref.watch(practiceControllerProvider);
    ref.listen(
      practiceControllerProvider.select((a) => a.value?.limitReached ?? false),
      (previous, reached) {
        if (reached && previous != true) {
          openPaywall(context, trigger: PaywallTrigger.dailyLimit);
        }
      },
    );
    final state = async.value;
    final inQuestion =
        state != null &&
        !state.finished &&
        !state.limitReached &&
        state.current != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(practiceModeTitle(local, args.mode)),
        actions: [
          if (inQuestion)
            IconButton(
              key: const Key('practice_bookmark'),
              tooltip: state.bookmarked.contains(state.current!.id)
                  ? local.practiceBookmarkRemove
                  : local.practiceBookmarkAdd,
              icon: Icon(
                state.bookmarked.contains(state.current!.id)
                    ? Icons.bookmark
                    : Icons.bookmark_border,
              ),
              onPressed: controller.toggleBookmark,
            ),
          if (state != null && !state.finished && state.answeredCount > 0)
            IconButton(
              key: const Key('practice_finish'),
              tooltip: local.practiceFinishSession,
              icon: const Icon(Icons.flag_outlined),
              onPressed: controller.finish,
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(local.practiceLoadError),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => ref.invalidate(practiceControllerProvider),
                child: Text(local.bankRetryLabel),
              ),
            ],
          ),
        ),
        data: (state) => _content(context, ref, local, state),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations local,
    PracticeState state,
  ) {
    final controller = ref.read(practiceControllerProvider.notifier);
    if (state.finished) {
      return PracticeSummary(
        correct: state.correctCount,
        wrong: state.wrongCount,
        onRepeatMistakes: state.wrongIds.isEmpty
            ? null
            : () => Navigator.of(context).pushReplacement<void, void>(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      PracticeScreen(args: args.retry(state.wrongIds)),
                ),
              ),
        onBack: () => Navigator.of(context).pop(),
      );
    }
    if (state.queue.isEmpty) {
      return _Message(text: _emptyText(local), icon: Icons.inbox_outlined);
    }
    if (state.limitReached) {
      return _LimitView(onRecheck: controller.recheckLimit);
    }
    final question = state.current!;
    return Column(
      children: [
        if (state.bookmarkFailed)
          Semantics(
            liveRegion: true,
            container: true,
            child: Container(
              key: const Key('practice_bookmark_error'),
              width: double.infinity,
              color: Theme.of(context).colorScheme.errorContainer,
              padding: const EdgeInsets.all(8),
              child: Text(
                local.practiceBookmarkError,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ),
        _ProgressBar(
          current: state.index + (state.currentAnswered ? 1 : 0),
          total: state.queue.length,
        ),
        Expanded(
          child: QuestionView(
            key: ValueKey(question.id),
            question: question,
            shuffled: state.shuffles[question.id]!,
            requestedLanguage: state.language,
            selectedCanonical: state.selected[question.id],
            onAnswer: controller.answer,
            footer: state.currentUnsaved
                ? _SaveError(onRetry: controller.retrySave)
                : null,
          ),
        ),
        if (state.currentAnswered && !state.currentUnsaved)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('practice_next'),
                  onPressed: controller.next,
                  child: Text(
                    state.isLast
                        ? local.practiceLastQuestionButton
                        : local.nextQuestion,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _emptyText(AppLocalizations local) => switch (args.mode) {
    PracticeMode.mistakes => local.practiceEmptyMistakes,
    PracticeMode.review => local.practiceEmptyReview,
    PracticeMode.bookmarks => local.practiceEmptyBookmarks,
    _ => local.practiceEmptyLearn,
  };
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Semantics(
        label: local.practiceProgress(current, total),
        excludeSemantics: true,
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : current / total,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                local.practiceProgress(current, total),
                key: const Key('practice_progress'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            key: const Key('practice_empty'),
          ),
        ],
      ),
    ),
  );
}

class _LimitView extends StatelessWidget {
  const _LimitView({required this.onRecheck});

  final VoidCallback onRecheck;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_bottom, size: 48),
            const SizedBox(height: 12),
            Text(
              local.practiceLimitTitle,
              key: const Key('practice_limit'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              local.practiceLimitBody(AccessPolicy.freeDailyAnswers),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('practice_limit_premium'),
              onPressed: () => openPaywall(
                context,
                explicit: true,
                trigger: PaywallTrigger.dailyLimit,
              ),
              child: Text(local.goPremiumLabel),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('practice_limit_recheck'),
              onPressed: onRecheck,
              child: Text(local.practiceLimitRecheck),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(local.returnToSubjectTitle),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the answer of the current question could not be stored. The
/// answer does not count until a retry succeeds.
class _SaveError extends StatelessWidget {
  const _SaveError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        key: const Key('practice_save_error'),
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            Text(
              local.practiceSaveError,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
            TextButton(
              key: const Key('practice_save_retry'),
              onPressed: onRetry,
              child: Text(local.practiceSaveRetry),
            ),
          ],
        ),
      ),
    );
  }
}
