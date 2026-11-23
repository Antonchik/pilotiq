import 'package:pilotiq/src/bank/models.dart';
import 'package:pilotiq/src/domain/mistakes.dart';
import 'package:pilotiq/src/progress/question_progress.dart';

/// What a practice session is made of.
enum PracticeMode {
  /// Questions of the subject: not seen yet first, then the least accurate.
  learn,

  /// Questions whose Leitner review is due.
  review,

  /// Questions answered wrongly and not yet mastered.
  mistakes,

  /// Bookmarked questions.
  bookmarks,

  /// An explicit list of questions (mistakes of the previous session).
  retry,
}

/// Counters shown on the subject screen.
class SubjectStats {
  const SubjectStats({
    required this.total,
    required this.covered,
    required this.correct,
    required this.wrong,
    required this.due,
    required this.mistakes,
    required this.bookmarks,
  });

  static const empty = SubjectStats(
    total: 0,
    covered: 0,
    correct: 0,
    wrong: 0,
    due: 0,
    mistakes: 0,
    bookmarks: 0,
  );

  final int total;
  final int covered;
  final int correct;
  final int wrong;
  final int due;
  final int mistakes;
  final int bookmarks;

  int get unseen => total - covered;
  double get coverage => total == 0 ? 0 : covered / total;
  bool get hasAnswers => correct + wrong > 0;
  double get accuracy => hasAnswers ? correct / (correct + wrong) : 0;
}

bool _isSeen(QuestionProgress? p) => p != null && p.seen > 0;

bool _isDue(QuestionProgress? p, DateTime now) =>
    p != null && p.seen > 0 && p.dueAt != null && !p.dueAt!.isAfter(now);

/// Counters of [questions] (usually one subject) from the stored [progress].
SubjectStats computeSubjectStats(
  Iterable<Question> questions,
  Map<String, QuestionProgress> progress,
  DateTime now,
) {
  var total = 0;
  var covered = 0;
  var correct = 0;
  var wrong = 0;
  var due = 0;
  var mistakes = 0;
  var bookmarks = 0;
  for (final q in questions) {
    total++;
    final p = progress[q.id];
    if (p == null) continue;
    if (_isSeen(p)) {
      covered++;
      correct += p.correct;
      wrong += p.wrong;
    }
    if (_isDue(p, now)) due++;
    if (isMistake(p)) mistakes++;
    if (p.bookmarked) bookmarks++;
  }
  return SubjectStats(
    total: total,
    covered: covered,
    correct: correct,
    wrong: wrong,
    due: due,
    mistakes: mistakes,
    bookmarks: bookmarks,
  );
}

/// The questions of a session of [mode], in the order they are asked.
/// [questions] are the questions of the subject (in the order of the bank);
/// questions without stored progress are treated as not seen.
List<Question> buildPracticeQueue({
  required PracticeMode mode,
  required List<Question> questions,
  required Map<String, QuestionProgress> progress,
  required DateTime now,
  List<String> retryIds = const [],
}) {
  final base = _baseQueue(
    mode: mode,
    questions: questions,
    progress: progress,
    now: now,
    retryIds: retryIds,
  );
  if (mode == PracticeMode.learn) {
    // Not seen questions first, the other variants of a NUMER after the first
    // variants; then the questions that were answered before.
    final unseen = [
      for (final q in base)
        if (!_isSeen(progress[q.id])) q,
    ];
    final seen = [
      for (final q in base)
        if (_isSeen(progress[q.id])) q,
    ];
    return [
      ...spreadVariants(unseen, firstVariantsFirst: true),
      ...spreadVariants(seen),
    ];
  }
  return spreadVariants(base);
}

/// Reorders [questions] so that two variants of the same NUMER are not asked
/// one after another (the highlighted answer of the first variant would give
/// the second one away), unless nothing else is left. With
/// [firstVariantsFirst] the first variant of every NUMER goes before any
/// second variant. The relative order is otherwise kept.
List<Question> spreadVariants(
  List<Question> questions, {
  bool firstVariantsFirst = false,
}) {
  var rest = <Question>[...questions];
  if (firstVariantsFirst) {
    final rank = <String, int>{};
    final ranked = [
      for (final q in questions)
        (q, rank[q.number] = (rank[q.number] ?? -1) + 1),
    ];
    // Stable sort by variant rank.
    final maxRank = ranked.fold<int>(0, (m, e) => e.$2 > m ? e.$2 : m);
    rest = [
      for (var r = 0; r <= maxRank; r++)
        for (final e in ranked)
          if (e.$2 == r) e.$1,
    ];
  }
  final result = <Question>[];
  while (rest.isNotEmpty) {
    final last = result.isEmpty ? null : result.last.number;
    var index = rest.indexWhere((q) => q.number != last);
    if (index < 0) index = 0;
    result.add(rest.removeAt(index));
  }
  return result;
}

List<Question> _baseQueue({
  required PracticeMode mode,
  required List<Question> questions,
  required Map<String, QuestionProgress> progress,
  required DateTime now,
  List<String> retryIds = const [],
}) {
  final order = {for (var i = 0; i < questions.length; i++) questions[i].id: i};
  int byBank(Question a, Question b) => order[a.id]!.compareTo(order[b.id]!);
  switch (mode) {
    case PracticeMode.learn:
      final unseen = [
        for (final q in questions)
          if (!_isSeen(progress[q.id])) q,
      ];
      final seen = [
        for (final q in questions)
          if (_isSeen(progress[q.id])) q,
      ];
      double accuracy(Question q) {
        final p = progress[q.id]!;
        return p.correct / p.seen;
      }

      seen.sort((a, b) {
        final byAccuracy = accuracy(a).compareTo(accuracy(b));
        if (byAccuracy != 0) return byAccuracy;
        final pa = progress[a.id]!.lastAnsweredAt;
        final pb = progress[b.id]!.lastAnsweredAt;
        if (pa != null && pb != null && pa != pb) return pa.compareTo(pb);
        return byBank(a, b);
      });
      return [...unseen, ...seen];
    case PracticeMode.review:
      final due = [
        for (final q in questions)
          if (_isDue(progress[q.id], now)) q,
      ];
      due.sort((a, b) {
        final c = progress[a.id]!.dueAt!.compareTo(progress[b.id]!.dueAt!);
        return c != 0 ? c : byBank(a, b);
      });
      return due;
    case PracticeMode.mistakes:
      final list = [
        for (final q in questions)
          if (progress[q.id] != null && isMistake(progress[q.id]!)) q,
      ];
      list.sort((a, b) {
        final pa = progress[a.id]!.lastAnsweredAt;
        final pb = progress[b.id]!.lastAnsweredAt;
        if (pa != null && pb != null && pa != pb) return pa.compareTo(pb);
        return byBank(a, b);
      });
      return list;
    case PracticeMode.bookmarks:
      return [
        for (final q in questions)
          if (progress[q.id]?.bookmarked ?? false) q,
      ];
    case PracticeMode.retry:
      return [
        for (final id in retryIds)
          if (order.containsKey(id)) questions[order[id]!],
      ];
  }
}
