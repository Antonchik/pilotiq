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
///
/// Rule of the queue. First the questions get a priority order:
/// * `learn`: (1) not seen questions whose NUMER has no seen variant yet,
///   first variants of every NUMER before the second ones; (2) not seen
///   variants of NUMERs that were already touched; (3) seen questions by
///   ascending accuracy (older answer first, then bank order). The other
///   modes keep their own order (review: due date; mistakes: oldest answer;
///   bookmarks and retry: bank / given order).
///
/// Then [spreadVariants] is applied to the **whole** queue: two variants of
/// one NUMER never stand next to each other whenever such an order exists
/// (the highlighted answer of one variant would give the other away). A
/// question is moved behind a later one only when it would repeat the NUMER
/// of the previous question or when placing it would make a spread
/// impossible; so the priority order holds except for these shifts.
/// The result is deterministic.
List<Question> buildPracticeQueue({
  required PracticeMode mode,
  required List<Question> questions,
  required Map<String, QuestionProgress> progress,
  required DateTime now,
  List<String> retryIds = const [],
}) {
  final base = mode == PracticeMode.learn
      ? learnPriorityOrder(questions, progress)
      : _baseQueue(
          mode: mode,
          questions: questions,
          progress: progress,
          now: now,
          retryIds: retryIds,
        );
  return spreadVariants(base);
}

/// Priority order of the `learn` mode before variants are spread, see
/// [buildPracticeQueue].
List<Question> learnPriorityOrder(
  List<Question> questions,
  Map<String, QuestionProgress> progress,
) {
  final order = {for (var i = 0; i < questions.length; i++) questions[i].id: i};
  final rank = <String, int>{};
  final variantRank = <String, int>{};
  final touched = <String>{};
  for (final q in questions) {
    variantRank[q.id] = rank[q.number] = (rank[q.number] ?? -1) + 1;
    if (_isSeen(progress[q.id])) touched.add(q.number);
  }
  int byRank(Question a, Question b) {
    final c = variantRank[a.id]!.compareTo(variantRank[b.id]!);
    return c != 0 ? c : order[a.id]!.compareTo(order[b.id]!);
  }

  final fresh = <Question>[];
  final variantsOfTouched = <Question>[];
  final seen = <Question>[];
  for (final q in questions) {
    if (_isSeen(progress[q.id])) {
      seen.add(q);
    } else if (touched.contains(q.number)) {
      variantsOfTouched.add(q);
    } else {
      fresh.add(q);
    }
  }
  fresh.sort(byRank);
  variantsOfTouched.sort(byRank);
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
    return order[a.id]!.compareTo(order[b.id]!);
  });
  return [...fresh, ...variantsOfTouched, ...seen];
}

/// Whether numbers with the given [counts] (total [n]) can be put in a row
/// with no two equal neighbours, the first one differing from [last].
bool _canSpread(Map<String, int> counts, int n, String? last) {
  for (final e in counts.entries) {
    if (e.value == 0) continue;
    final limit = e.key == last ? n ~/ 2 : (n + 1) ~/ 2;
    if (e.value > limit) return false;
  }
  return true;
}

/// Whether [numbers] can be arranged so that no two equal ones are adjacent
/// (and the first one differs from [last]).
bool canSpreadNumbers(Iterable<String> numbers, {String? last}) {
  final counts = <String, int>{};
  var n = 0;
  for (final x in numbers) {
    counts[x] = (counts[x] ?? 0) + 1;
    n++;
  }
  return _canSpread(counts, n, last);
}

/// Reorders [questions] so that two variants of the same NUMER are not asked
/// one after another, whenever such an order exists. At every step the
/// earliest remaining question is taken that (a) does not repeat the NUMER of
/// the previous one and (b) leaves a remainder that can still be spread. If
/// no spread exists, the earliest question with another NUMER is taken (and
/// the order is kept as it is when even that is impossible).
List<Question> spreadVariants(List<Question> questions) {
  final rest = <Question>[...questions];
  final counts = <String, int>{};
  for (final q in rest) {
    counts[q.number] = (counts[q.number] ?? 0) + 1;
  }
  final result = <Question>[];
  var possible = _canSpread(counts, rest.length, null);
  while (rest.isNotEmpty) {
    final last = result.isEmpty ? null : result.last.number;
    // The two largest counts of this step (one pass over the numbers): what
    // is left after taking a question is spreadable when its own NUMER, one
    // less, fits [remaining ~/ 2] and the largest of the others fits
    // [(remaining + 1) ~/ 2]. This is [_canSpread] without trying every
    // number for every candidate.
    String? topNumber;
    var top = 0;
    var second = 0;
    if (possible) {
      for (final e in counts.entries) {
        if (e.value > top) {
          second = top;
          top = e.value;
          topNumber = e.key;
        } else if (e.value > second) {
          second = e.value;
        }
      }
    }
    final remaining = rest.length - 1;
    var pick = -1;
    var firstOther = -1;
    for (var i = 0; i < rest.length; i++) {
      final number = rest[i].number;
      if (number == last) continue;
      if (firstOther < 0) firstOther = i;
      if (!possible) break;
      final others = number == topNumber ? second : top;
      if (counts[number]! - 1 <= remaining ~/ 2 &&
          others <= (remaining + 1) ~/ 2) {
        pick = i;
        break;
      }
    }
    if (pick < 0) {
      pick = firstOther >= 0 ? firstOther : 0;
      possible = false;
    }
    final q = rest.removeAt(pick);
    counts[q.number] = counts[q.number]! - 1;
    result.add(q);
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
      return learnPriorityOrder(questions, progress);
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
