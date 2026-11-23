import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:pilotiq/src/bank/licence_provider.dart';
import 'package:pilotiq/src/bank/question_bank_repository.dart';
import 'package:pilotiq/src/dashboard/dashboard_data.dart';
import 'package:pilotiq/src/dashboard/dashboard_providers.dart';
import 'package:pilotiq/src/domain/access_policy.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/purchases/paywall_launcher.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';
import 'package:pilotiq/src/settings/settings_tiles.dart';
import 'package:pilotiq/src/subjects/subject_info.dart';

int _percent(double fraction) => (fraction * 100).round().clamp(0, 100);

/// "Today" tab: exam countdown, daily goal, streak, repetitions due, basic
/// statistics, readiness, weak subjects and the last simulation.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    final data = ref.watch(dashboardProvider);
    return Scaffold(
      appBar: AppBar(title: Text(local.dashboardTitle)),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(local.bankLoadError, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const Key('dashboard_retry'),
                  onPressed: () {
                    final licence = ref.read(selectedLicenceProvider);
                    ref.invalidate(bankProvider(licence));
                    ref.invalidate(dashboardProvider);
                  },
                  child: Text(local.bankRetryLabel),
                ),
              ],
            ),
          ),
        ),
        data: (data) => _DashboardBody(data: data),
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(dashboardProvider),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _ExamCountdownCard(daysLeft: data.examDaysLeft),
          _GoalCard(data: data),
          _StreakCard(data: data),
          _DueCard(data: data, isPremium: isPremium),
          _OverviewCard(data: data),
          _ReadinessCard(data: data, isPremium: isPremium),
          _WeakCard(data: data),
          _LastExamCard(data: data),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.onTap,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(title, style: textTheme.titleMedium),
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _ExamCountdownCard extends ConsumerWidget {
  const _ExamCountdownCard({required this.daysLeft});

  final int? daysLeft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    final days = daysLeft;
    final String text;
    if (days == null) {
      text = local.dashboardExamNotSet;
    } else if (days < 0) {
      text = local.dashboardExamPassed;
    } else {
      text = local.dashboardExamCountdown(days);
    }
    final showAction = days == null || days < 0;
    return Card(
      key: const Key('dashboard_exam'),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.event_available, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.titleMedium),
            ),
            if (showAction)
              TextButton(
                key: const Key('dashboard_exam_set'),
                onPressed: () async {
                  final picked = await pickExamDate(context, ref);
                  if (picked == null || !context.mounted) return;
                  await changeSettings(
                    context,
                    ref,
                    (s) => s.copyWith(examDate: picked),
                  );
                },
                child: Text(local.dashboardExamSetDate),
              ),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return _CardShell(
      key: const Key('dashboard_goal'),
      title: local.dashboardGoalTitle,
      child: Row(
        children: [
          CircularPercentIndicator(
            radius: 44,
            lineWidth: 9,
            percent: data.goalFraction,
            progressColor: data.goalReached ? Colors.green : colors.primary,
            backgroundColor: colors.surfaceContainerHighest,
            circularStrokeCap: CircularStrokeCap.round,
            center: Text(
              local.dashboardGoalValue(data.answeredToday, data.dailyGoal),
              key: const Key('dashboard_goal_value'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              data.goalReached
                  ? local.dashboardGoalReached
                  : local.dashboardGoalRemaining(data.goalRemaining),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    return _CardShell(
      key: const Key('dashboard_streak'),
      title: local.dashboardStreakTitle,
      trailing: Icon(
        Icons.local_fire_department,
        color: data.streak.current > 0 ? Colors.deepOrange : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            local.dashboardStreak(data.streak.current),
            key: const Key('dashboard_streak_value'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            local.dashboardStreakHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _DueCard extends ConsumerWidget {
  const _DueCard({required this.data, required this.isPremium});

  final DashboardData data;
  final bool isPremium;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    final canReview = AccessPolicy.canUseReview(isPremium);
    return _CardShell(
      key: const Key('dashboard_due'),
      title: local.dashboardDueTitle,
      trailing: canReview ? null : const Icon(Icons.lock_outline, size: 20),
      onTap: () {
        if (!canReview) {
          openPaywall(context, trigger: PaywallTrigger.lockedFeature);
        } else {
          // Review is started per subject (the "Review" tile of a subject),
          // so the card leads to the subject list.
          ref.read(homeTabProvider.notifier).state = 1;
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            local.dashboardDue(data.dueToday),
            key: const Key('dashboard_due_value'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            canReview ? local.dashboardDueHint : local.dashboardDueLocked,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    return _CardShell(
      key: const Key('dashboard_overview'),
      title: local.dashboardOverviewTitle,
      child: Row(
        children: [
          Expanded(
            child: _Metric(
              label: local.dashboardCoverage(_percent(data.coverage)),
              fraction: data.coverage,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _Metric(
              label: local.dashboardAccuracy(_percent(data.accuracy)),
              fraction: data.accuracy,
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.fraction});

  final String label;
  final double fraction;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      const SizedBox(height: 6),
      LinearProgressIndicator(
        value: fraction.clamp(0.0, 1.0),
        minHeight: 8,
        borderRadius: BorderRadius.circular(4),
      ),
    ],
  );
}

Color _levelColor(ReadinessLevel level) => switch (level) {
  ReadinessLevel.low => Colors.red,
  ReadinessLevel.medium => Colors.amber.shade700,
  ReadinessLevel.high => Colors.green,
};

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({required this.data, required this.isPremium});

  final DashboardData data;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final detail = AccessPolicy.canUseReadinessDetail(isPremium);
    return _CardShell(
      key: const Key('dashboard_readiness'),
      title:
          '${local.dashboardReadinessTitle} (${local.dashboardReadinessApprox})',
      trailing: detail ? null : const Icon(Icons.lock_outline, size: 20),
      onTap: detail
          ? null
          : () => openPaywall(context, trigger: PaywallTrigger.lockedFeature),
      child: detail
          ? Column(
              children: [
                for (final s in data.subjects)
                  _ReadinessRow(
                    key: Key('readiness_${s.subject.id}'),
                    stats: s,
                  ),
              ],
            )
          : Text(
              key: const Key('dashboard_readiness_locked'),
              local.dashboardReadinessLocked,
            ),
    );
  }
}

class _ReadinessRow extends StatelessWidget {
  const _ReadinessRow({super.key, required this.stats});

  final SubjectStats stats;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final color = _levelColor(stats.level);
    // 100 % is never promised: round down.
    final percent = (stats.readiness * 100).floor().clamp(0, 100);
    final title = subjectTitle(local, stats.subject);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Semantics(
        label:
            '$title ${local.dashboardPercentValue(percent)} '
            '${local.dashboardReadinessApprox}',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title)),
                Text(
                  local.dashboardPercentValue(percent),
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: stats.readiness.clamp(0.0, 1.0),
              minHeight: 6,
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeakCard extends StatelessWidget {
  const _WeakCard({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    return _CardShell(
      key: const Key('dashboard_weak'),
      title: local.dashboardWeakTitle,
      child: data.weakSubjects.isEmpty
          ? Text(local.dashboardWeakNone)
          : Column(
              children: [
                for (final s in data.weakSubjects)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(subjectTitle(local, s.subject)),
                    trailing: Text(
                      local.dashboardPercentValue(_percent(s.accuracy)),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _LastExamCard extends StatelessWidget {
  const _LastExamCard({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final last = data.lastAttempt;
    final Widget body;
    if (last != null) {
      final percent = last.total == 0 ? 0 : _percent(last.correct / last.total);
      final date = MaterialLocalizations.of(context)
          .formatMediumDate(last.finishedAt.toLocal());
      body = ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(subjectTitle(local, last.subject)),
        subtitle: Text(local.dashboardAttemptResult(percent, date)),
        trailing: Chip(
          label: Text(
            last.passed ? local.dashboardPassed : local.dashboardFailed,
          ),
          backgroundColor: last.passed
              ? Colors.green.withValues(alpha: 0.2)
              : Colors.red.withValues(alpha: 0.2),
        ),
      );
    } else {
      body = Text(local.dashboardLastExamNone);
    }
    return _CardShell(
      key: const Key('dashboard_last_exam'),
      title: local.dashboardLastExamTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          body,
          if (data.legacyAttempts > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                local.dashboardLegacyAttempts(data.legacyAttempts),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
