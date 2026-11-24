import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/bank/bank_text.dart';
import 'package:pilotiq/src/bank/models.dart';
import 'package:pilotiq/src/exam_sim/exam_controller.dart';
import 'package:pilotiq/src/exam_sim/exam_entry.dart';
import 'package:pilotiq/src/exam_sim/exam_format.dart';
import 'package:pilotiq/src/exam_sim/exam_results_screen.dart';
import 'package:pilotiq/src/exam_sim/question_grid.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/progress/user_settings.dart';
import 'package:pilotiq/src/progress/providers.dart';
import 'package:pilotiq/src/purchases/paywall_launcher.dart';

/// The exam simulation of one subject: rules, the exam itself, the saving of
/// the result and the result. The state belongs to this screen only.
class ExamScreen extends ConsumerStatefulWidget {
  const ExamScreen({super.key, required this.args});

  final ExamArgs args;

  @override
  ConsumerState<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends ConsumerState<ExamScreen> {
  late final _overrides = [
    examControllerProvider.overrideWith(() => ExamController(widget.args)),
  ];

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: _overrides,
    child: _ExamBody(args: widget.args),
  );
}

class _ExamBody extends ConsumerStatefulWidget {
  const _ExamBody({required this.args});

  final ExamArgs args;

  @override
  ConsumerState<_ExamBody> createState() => _ExamBodyState();
}

class _ExamBodyState extends ConsumerState<_ExamBody>
    with WidgetsBindingObserver {
  final List<BuildContext> _modals = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(examControllerProvider.notifier).syncTime();
    }
  }

  ExamController get _controller => ref.read(examControllerProvider.notifier);

  /// Shows [show] and remembers the route's context while it is open, so
  /// that [_closeModals] can close it; it is forgotten as soon as the route
  /// is popped (even while it still animates away).
  Future<T?> _tracked<T>(
    Future<T?> Function(Widget Function(BuildContext) wrap) show,
    WidgetBuilder builder,
  ) {
    Object? route;
    return show((ctx) {
      route = ctx;
      if (!_modals.contains(ctx)) _modals.add(ctx);
      return builder(ctx);
    }).whenComplete(() => _modals.removeWhere((c) => identical(c, route)));
  }

  Future<T?> _dialog<T>(WidgetBuilder builder) {
    if (!mounted) return Future.value();
    final host = context;
    return _tracked<T>(
      (wrap) => showDialog<T>(context: host, builder: wrap),
      builder,
    );
  }

  /// Closes dialogs and sheets that are open when the exam ends by itself.
  void _closeModals() {
    for (final c in _modals.toList()) {
      if (c.mounted) Navigator.of(c).pop();
    }
    _modals.clear();
  }

  Future<void> _confirmFinish(ExamState s) async {
    final local = AppLocalizations.of(context)!;
    final ok = await _dialog<bool>(
      (ctx) => AlertDialog(
        scrollable: true,
        title: Text(local.examFinishDialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              local.examFinishUnanswered(s.unansweredCount),
              key: const Key('exam_finish_unanswered'),
            ),
            if (s.unansweredCount > 0) Text(local.examFinishUnansweredNote),
            const SizedBox(height: 8),
            Text(
              local.examFinishFlagged(s.flaggedCount),
              key: const Key('exam_finish_flagged'),
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const Key('exam_finish_cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(local.examFinishKeepWorking),
          ),
          FilledButton(
            key: const Key('exam_finish_confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(local.examFinishConfirm),
          ),
        ],
      ),
    );
    if (ok == true) await _controller.finish();
  }

  Future<void> _confirmLeave() async {
    final local = AppLocalizations.of(context)!;
    final leave = await _dialog<bool>(
      (ctx) => AlertDialog(
        scrollable: true,
        title: Text(local.examLeaveTitle),
        content: Text(local.examLeaveBody),
        actions: [
          TextButton(
            key: const Key('exam_leave_stay'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(local.examLeaveStay),
          ),
          FilledButton(
            key: const Key('exam_leave_confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(local.examLeaveConfirm),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _openGrid(ExamState s) async {
    final local = AppLocalizations.of(context)!;
    final picked = await _tracked<int>(
      (wrap) => showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: wrap,
      ),
      (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    local.examGridTitle,
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: QuestionGrid(
                    count: s.questions.length,
                    currentIndex: s.index,
                    isAnswered: (i) => s.answers.containsKey(s.questions[i].id),
                    isFlagged: (i) => s.flagged.contains(s.questions[i].id),
                    onSelect: (i) => Navigator.of(ctx).pop(i),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextButton(
                    key: const Key('exam_grid_close'),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(local.examGridClose),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null && mounted) _controller.goTo(picked);
  }

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    ref.listen(examControllerProvider.select((a) => a.value?.phase), (
      previous,
      phase,
    ) {
      if (phase == ExamPhase.finishing || phase == ExamPhase.done) {
        _closeModals();
      }
      if (phase == ExamPhase.limit && previous != ExamPhase.limit) {
        openPaywall(context, trigger: PaywallTrigger.examLimit);
      }
    });
    final async = ref.watch(examControllerProvider);
    final s = async.value;
    if (s != null && s.phase == ExamPhase.done && s.attempt != null) {
      return ExamResultsScreen(
        attempt: s.attempt!,
        args: widget.args,
        notice: s.notice,
        onRepeat: () => Navigator.of(context).pushReplacement<void, void>(
          MaterialPageRoute<void>(
            builder: (_) => ExamScreen(args: widget.args),
          ),
        ),
      );
    }
    final running = s != null && s.phase == ExamPhase.running;
    return PopScope(
      canPop: !running,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            local.examScreenTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (running) ...[
              IconButton(
                key: const Key('exam_grid_button'),
                tooltip: local.examGridTooltip,
                icon: const Icon(Icons.grid_view),
                onPressed: () => _openGrid(s),
              ),
              IconButton(
                key: const Key('exam_finish_button'),
                tooltip: local.examFinishTooltip,
                icon: const Icon(Icons.task_alt),
                onPressed: () => _confirmFinish(s),
              ),
            ],
          ],
        ),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _Message(
            icon: Icons.error_outline,
            title: local.practiceLoadError,
            children: [
              OutlinedButton(
                onPressed: () => ref.invalidate(examControllerProvider),
                child: Text(local.bankRetryLabel),
              ),
            ],
          ),
          data: (state) => switch (state.phase) {
            ExamPhase.rules => _RulesView(args: widget.args, state: state),
            ExamPhase.limit => _LimitView(args: widget.args),
            ExamPhase.resume => _ResumeView(state: state),
            ExamPhase.running => _RunningView(
              state: state,
              onFinish: () => _confirmFinish(state),
            ),
            ExamPhase.finishing ||
            ExamPhase.done => _FinishingView(failed: state.finishFailed),
          },
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    this.body,
    this.children = const [],
  });

  final IconData icon;
  final String title;
  final String? body;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          if (body != null) ...[
            const SizedBox(height: 8),
            Text(body!, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );
}

class _RulesView extends ConsumerWidget {
  const _RulesView({required this.args, required this.state});

  final ExamArgs args;
  final ExamState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    final controller = ref.read(examControllerProvider.notifier);
    final n = args.spec.quizLength < args.questions.length
        ? args.spec.quizLength
        : args.questions.length;
    Widget row(IconData icon, String text, {Key? key}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(child: Text(text, key: key)),
        ],
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          local.examRulesHeading,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        row(
          Icons.list,
          local.examRulesQuestions(n),
          key: const Key('rules_questions'),
        ),
        row(
          Icons.timer_outlined,
          local.examRulesTime(args.spec.minutes),
          key: const Key('rules_time'),
        ),
        row(Icons.check_circle_outline, local.examRulesPass(args.passPercent)),
        row(Icons.swap_horiz, local.examRulesNavigate),
        row(Icons.flag_outlined, local.examRulesNoFeedback),
        row(Icons.hourglass_bottom, local.examRulesTimer),
        row(Icons.shuffle, local.examRulesFresh),
        if (state.startFailed)
          _ErrorBox(
            key: const Key('exam_start_error'),
            text: local.examStartFailed,
            onRetry: controller.start,
          ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('exam_start'),
          onPressed: args.questions.isEmpty ? null : controller.start,
          child: Text(local.examStartButton),
        ),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({super.key, required this.text, required this.onRetry});

  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer),
            Text(text, style: TextStyle(color: scheme.onErrorContainer)),
            TextButton(
              key: const Key('exam_retry'),
              onPressed: onRetry,
              child: Text(local.examSaveRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class _LimitView extends ConsumerWidget {
  const _LimitView({required this.args});

  final ExamArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    return _Message(
      icon: Icons.lock_outline,
      title: local.examLimitTitle,
      body: local.examLimitBody,
      children: [
        FilledButton(
          key: const Key('exam_limit_premium'),
          onPressed: () =>
              openPaywall(context, trigger: PaywallTrigger.examLimit),
          child: Text(local.goPremiumLabel),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('exam_limit_history'),
          onPressed: () => openExamHistory(context, args),
          child: Text(local.examLimitHistory),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const Key('exam_limit_back'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(local.returnToSubjectTitle),
        ),
      ],
    );
  }
}

class _ResumeView extends ConsumerWidget {
  const _ResumeView({required this.state});

  final ExamState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    final controller = ref.read(examControllerProvider.notifier);
    final left = state.deadline!.difference(ref.read(clockProvider).now());
    return _Message(
      icon: Icons.restore,
      title: local.examResumeTitle,
      body: local.examResumeBody(
        state.answeredCount,
        state.questions.length,
        ceilMinutes(left),
      ),
      children: [
        FilledButton(
          key: const Key('exam_resume'),
          onPressed: controller.resume,
          child: Text(local.examResumeContinue),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('exam_resume_finish'),
          onPressed: controller.finishFromResume,
          child: Text(local.examResumeFinish),
        ),
      ],
    );
  }
}

class _FinishingView extends ConsumerWidget {
  const _FinishingView({required this.failed});

  final bool failed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    if (!failed) {
      return Center(
        child: Semantics(
          liveRegion: true,
          label: local.examSavingResult,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(local.examSavingResult),
            ],
          ),
        ),
      );
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _ErrorBox(
          key: const Key('exam_finish_error'),
          text: local.examFinishSaveError,
          onRetry: ref.read(examControllerProvider.notifier).retryFinish,
        ),
      ),
    );
  }
}

class _RunningView extends ConsumerWidget {
  const _RunningView({required this.state, required this.onFinish});

  final ExamState state;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    final controller = ref.read(examControllerProvider.notifier);
    final q = state.current!;
    final isLast = state.index >= state.questions.length - 1;
    return Column(
      children: [
        if (state.persistFailed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _ErrorBox(
              key: const Key('exam_persist_error'),
              text: local.examPersistError,
              onRetry: controller.retryPersist,
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Wrap(
            spacing: 16,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _TimerChip(remaining: controller.remaining),
              Text(
                local.examQuestionOf(state.index + 1, state.questions.length),
                key: const Key('exam_position'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                local.examAnsweredCount(state.answeredCount),
                key: const Key('exam_answered'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: _ExamQuestionView(
            key: ValueKey(q.id),
            question: q,
            shuffled: state.shuffles[q.id]!,
            language: state.language,
            selected: state.answers[q.id],
            flagged: state.flagged.contains(q.id),
            onAnswer: controller.answer,
            onToggleFlag: controller.toggleFlag,
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: OverflowBar(
              alignment: MainAxisAlignment.spaceBetween,
              overflowAlignment: OverflowBarAlignment.center,
              spacing: 8,
              overflowSpacing: 8,
              children: [
                OutlinedButton(
                  key: const Key('exam_prev'),
                  onPressed: state.index > 0 ? controller.previous : null,
                  child: Text(local.examPrevious),
                ),
                if (isLast)
                  FilledButton(
                    key: const Key('exam_finish_inline'),
                    onPressed: onFinish,
                    child: Text(local.examFinishButton),
                  )
                else
                  FilledButton(
                    key: const Key('exam_next'),
                    onPressed: controller.next,
                    child: Text(local.examNext),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The clock. It repaints once per second on its own and tells a screen
/// reader the whole minutes only (no live region: nothing is announced each
/// second).
class _TimerChip extends StatelessWidget {
  const _TimerChip({required this.remaining});

  final ValueListenable<Duration> remaining;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<Duration>(
      valueListenable: remaining,
      builder: (context, left, _) {
        final low = left <= const Duration(minutes: 5);
        return Semantics(
          label: local.examTimeLeftSemantics(ceilMinutes(left)),
          excludeSemantics: true,
          child: Container(
            key: const Key('exam_timer'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: low ? scheme.error : scheme.outline,
                width: low ? 2 : 1,
              ),
            ),
            child: Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(
                  low ? Icons.warning_amber : Icons.timer_outlined,
                  size: 18,
                ),
                Text(
                  formatClock(left),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (low) Text(local.examTimeLow),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ExamQuestionView extends StatelessWidget {
  const _ExamQuestionView({
    super.key,
    required this.question,
    required this.shuffled,
    required this.language,
    required this.selected,
    required this.flagged,
    required this.onAnswer,
    required this.onToggleFlag,
  });

  final Question question;
  final ShuffledAnswers shuffled;
  final QuestionLanguage language;
  final int? selected;
  final bool flagged;
  final ValueChanged<int> onAnswer;
  final VoidCallback onToggleFlag;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final shown = question.displayLanguage(language);
    final fellBack =
        language == QuestionLanguage.en && shown == QuestionLanguage.pl;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        BankText(
          question.text.resolve(shown),
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
        for (var p = 0; p < shuffled.length; p++)
          _ExamAnswerTile(
            key: ValueKey('answer_$p'),
            text: question.answers[shuffled.canonicalIndexAt(p)].resolve(shown),
            position: p + 1,
            total: shuffled.length,
            selected: selected == shuffled.canonicalIndexAt(p),
            onTap: () => onAnswer(p),
          ),
        OutlinedButton.icon(
          key: const Key('exam_flag'),
          icon: Icon(flagged ? Icons.flag : Icons.flag_outlined),
          label: Text(flagged ? local.examFlagRemove : local.examFlagAdd),
          onPressed: onToggleFlag,
        ),
      ],
    );
  }
}

/// An answer of the running exam: chosen or not, never right or wrong.
class _ExamAnswerTile extends StatelessWidget {
  const _ExamAnswerTile({
    super.key,
    required this.text,
    required this.position,
    required this.total,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final int position;
  final int total;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      onTap: onTap,
      label: local.examAnswerSemantics(position, total, bankPlainText(text)),
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: selected ? scheme.primaryContainer : null,
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 3 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BankText(
                    text,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
