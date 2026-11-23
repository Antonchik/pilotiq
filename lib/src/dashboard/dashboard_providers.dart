import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:pilotiq/src/bank/question_bank_repository.dart';
import 'package:pilotiq/src/dashboard/dashboard_data.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/progress/providers.dart';

/// Index of the selected tab of the home screen (0 Today, 1 Subjects,
/// 2 Profile).
final homeTabProvider = StateProvider<int>((ref) => 0);

/// The question bank could not be loaded (as opposed to the progress data).
class BankLoadFailure implements Exception {
  const BankLoadFailure(this.cause);

  final Object cause;

  @override
  String toString() => 'BankLoadFailure($cause)';
}

/// Data of the "Today" screen. Not kept alive: it is recomputed every time
/// the tab is shown again, when the app returns from the background and when
/// the local calendar day changes.
final dashboardProvider = FutureProvider.autoDispose<DashboardData>((
  ref,
) async {
  final settings = await ref.watch(userSettingsProvider.future);
  final licence = settings.licence;
  final repository = ref.watch(progressRepositoryProvider);
  final now = ref.watch(clockProvider).now();

  // Recompute when the local day changes while the screen stays open.
  final untilNextDay =
      endOfLocalDay(now).difference(now) + const Duration(milliseconds: 1);
  final timer = Timer(untilNextDay, ref.invalidateSelf);
  ref.onDispose(timer.cancel);

  final QuestionBank bank;
  try {
    bank = await ref.watch(bankProvider(licence).future);
  } on Object catch (e) {
    throw BankLoadFailure(e);
  }
  final progress = await repository.allProgress(licence);
  final horizon = endOfLocalDay(now);
  return DashboardData.compute(
    licence: licence,
    now: now,
    examDate: settings.examDate,
    dailyGoal: settings.dailyGoal,
    bankQids: {
      for (final subject in bank.subjects)
        subject: [for (final q in bank.questionsOf(subject)) q.id],
    },
    progress: progress,
    dailyStats: await repository.dailyStats(),
    attempts: await repository.attempts(licence),
    dueQids: [
      for (final p in progress.values)
        if (p.seen > 0 && p.dueAt != null && !p.dueAt!.isAfter(horizon)) p.qid,
    ],
  );
});

/// Licence whose migrated 1.x results are the most numerous, or null when
/// there are none. Used to pre-select the licence for upgrading users.
final legacyLicenceHintProvider = FutureProvider<Licence?>((ref) async {
  final repository = ref.watch(progressRepositoryProvider);
  Licence? best;
  var bestCount = 0;
  for (final licence in Licence.values) {
    final count = (await repository.attempts(licence))
        .where((a) => a.isLegacy)
        .length;
    if (count > bestCount) {
      best = licence;
      bestCount = count;
    }
  }
  return best;
});
