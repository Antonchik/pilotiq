import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/exam_sim/exam_controller.dart';
import 'package:pilotiq/src/exam_sim/exam_entry.dart';
import 'package:pilotiq/src/exam_sim/exam_format.dart';
import 'package:pilotiq/src/exam_sim/exam_results_screen.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/progress/exam_attempt.dart';
import 'package:pilotiq/src/progress/providers.dart';
import 'package:pilotiq/src/quiz/practice/practice_controller.dart';

/// Attempts of a subject, newest first.
final examHistoryProvider = FutureProvider.autoDispose
    .family<List<ExamAttempt>, SubjectKey>(
      (ref, key) => ref
          .watch(progressRepositoryProvider)
          .attempts(key.licence, subject: key.subject),
    );

class ExamHistoryScreen extends ConsumerWidget {
  const ExamHistoryScreen({super.key, required this.args});

  final ExamArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    final key = (licence: args.licence, subject: args.subject);
    final async = ref.watch(examHistoryProvider(key));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          local.examHistoryTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(local.examHistoryLoadError),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => ref.invalidate(examHistoryProvider(key)),
                child: Text(local.bankRetryLabel),
              ),
            ],
          ),
        ),
        data: (attempts) => attempts.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    local.examHistoryEmpty,
                    key: const Key('exam_history_empty'),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : _HistoryList(attempts: attempts, args: args),
      ),
    );
  }
}

class _HistoryList extends ConsumerWidget {
  const _HistoryList({required this.attempts, required this.args});

  final List<ExamAttempt> attempts;
  final ExamArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    // Newest first in the list; the chart reads oldest to newest.
    // Migrated (legacy) attempts have no result to chart.
    final recent = attempts
        .where((a) => !a.isLegacy)
        .take(10)
        .toList()
        .reversed
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          local.examHistoryChartTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        _Chart(attempts: recent, passPercent: args.passPercent),
        const SizedBox(height: 16),
        for (final a in attempts)
          _AttemptTile(
            key: ValueKey('history_${a.id}'),
            attempt: a,
            args: args,
            onChanged: () => ref.invalidate(
              examHistoryProvider((
                licence: args.licence,
                subject: args.subject,
              )),
            ),
          ),
      ],
    );
  }
}

int _percent(ExamAttempt a) => (a.ratio * 100).round();

/// Last results as bars, oldest on the left. Passed bars are filled, failed
/// bars are outlined; the pass mark is a line.
class _Chart extends StatelessWidget {
  const _Chart({required this.attempts, required this.passPercent});

  final List<ExamAttempt> attempts;
  final int passPercent;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    const height = 100.0;
    return Semantics(
      label: local.examHistoryChartSemantics(
        attempts.map((a) => '${_percent(a)}%').join(', '),
      ),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            key: const Key('exam_history_chart'),
            height: height,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: height * passPercent / 100,
                  child: Container(height: 1, color: scheme.outline),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final a in attempts)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Container(
                            height: (height * _percent(a) / 100).clamp(
                              2.0,
                              height,
                            ),
                            decoration: BoxDecoration(
                              color: a.passed ? scheme.primary : null,
                              border: Border.all(
                                color: scheme.primary,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            local.examHistoryPassLine(passPercent),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _AttemptTile extends StatelessWidget {
  const _AttemptTile({
    super.key,
    required this.attempt,
    required this.args,
    required this.onChanged,
  });

  final VoidCallback onChanged;

  final ExamAttempt attempt;
  final ExamArgs args;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final a = attempt;
    final legacy = a.isLegacy;
    final when = legacy
        ? local.examHistoryLegacy
        : formatDateTime(context, a.startedAt);
    final details = [
      if (!legacy) local.examResultCorrect(a.correct, a.total),
      if (!legacy)
        local.examResultTime(formatClock(Duration(seconds: a.durationSec))),
      if (a.reason == AttemptReason.timeout) local.examHistoryTimedOut,
    ];
    return Semantics(
      container: true,
      button: !legacy,
      excludeSemantics: true,
      label:
          '$when, ${legacy ? '' : '${_percent(a)}%, '}'
          '${a.passed ? local.examPassed : local.examFailed}, '
          '${details.join(', ')}',
      onTap: legacy ? null : () => _open(context),
      child: Card(
        child: ListTile(
          onTap: legacy ? null : () => _open(context),
          title: Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (!legacy)
                Text(
                  '${_percent(a)}%',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              PassBadge(passed: a.passed),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(when), for (final d in details) Text(d)],
          ),
          trailing: legacy ? null : const Icon(Icons.chevron_right),
        ),
      ),
    );
  }

  void _open(BuildContext context) => Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => ExamResultsScreen(
        attempt: attempt,
        args: args,
        onRepeat: () async {
          await openExamSimulation(context, args);
          onChanged();
        },
      ),
    ),
  );
}
