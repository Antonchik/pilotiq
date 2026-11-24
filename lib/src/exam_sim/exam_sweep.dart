import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/bank/question_bank_repository.dart';
import 'package:pilotiq/src/dashboard/dashboard_providers.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/exam_sim/exam_controller.dart';
import 'package:pilotiq/src/progress/providers.dart';
import 'package:pilotiq/src/quiz/practice/practice_controller.dart';

/// Closes the exams that have to be closed without the user, for every
/// licence: unfinished attempts whose time is over (they are stored as
/// `timeout`) and stored attempts whose answers are not counted yet. Run at
/// the start of the app and whenever it comes back to the front. Banks are
/// loaded only for licences that have something to do. Never throws.
final examSweepProvider = FutureProvider<int>((ref) async {
  final repo = ref.read(progressRepositoryProvider);
  final finalizer = ref.read(examFinalizerProvider);
  final now = ref.read(clockProvider).now();
  var closed = 0;
  var counted = 0;
  for (final licence in Licence.values) {
    try {
      final unfinished = [
        for (final s in SubjectId.values)
          ?await repo.loadInProgressAttempt(licence, s),
      ];
      final pending = await repo.attemptsWithUnrecordedAnswers(licence);
      if (unfinished.isEmpty && pending.isEmpty) continue;
      final bank = await ref.read(bankProvider(licence).future);
      final byId = {for (final q in bank.questions) q.id: q};
      for (final u in unfinished) {
        final left = await settleUnfinished(
          repo: repo,
          finalizer: finalizer,
          u: u,
          byId: byId,
          now: now,
        );
        if (left == null) closed++;
      }
      counted += await finalizer.completePending(licence, byId, now);
    } on Object catch (e) {
      debugPrint('Exam sweep of ${licence.id} failed: $e');
    }
  }
  if (closed > 0 || counted > 0) {
    ref.invalidate(dashboardProvider);
    // Whatever is open (subject screen) shows the new state.
    ref.invalidate(examStatusProvider);
    ref.invalidate(subjectStatsProvider);
  }
  return closed;
});

/// Runs the sweep again now (the result is not needed).
void runExamSweep(WidgetRef ref) {
  ref.invalidate(examSweepProvider);
  ref.read(examSweepProvider.future).ignore();
}
