import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilotiq/src/bank/question_bank_repository.dart';
import 'package:pilotiq/src/bank/models.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/progress/question_progress.dart';
import 'package:pilotiq/src/quiz/practice/practice_session.dart';

Question q(String id, [String? number]) => Question(
  id: id,
  number: number ?? id,
  topic: id.substring(0, 5),
  subject: SubjectId.airLaw,
  text: LocalizedText(pl: id),
  answers: [for (var i = 0; i < 4; i++) LocalizedText(pl: 'a$i')],
  correctIndex: 0,
);

List<String> ids(List<Question> l) => [for (final x in l) x.id];

void main() {
  final now = DateTime(2026, 5, 10, 12);
  final questions = [for (var i = 1; i <= 5; i++) q('PL010-000$i')];

  QuestionProgress p(
    String id, {
    int correct = 0,
    int wrong = 0,
    int consecutive = 0,
    DateTime? last,
    DateTime? due,
    bool bookmarked = false,
  }) => QuestionProgress(
    qid: id,
    seen: correct + wrong,
    correct: correct,
    wrong: wrong,
    consecutiveCorrect: consecutive,
    lastAnsweredAt: last,
    dueAt: due,
    bookmarked: bookmarked,
  );

  test('learn: not seen first (bank order), then ascending accuracy', () {
    final progress = {
      'PL010-0001': p('PL010-0001', correct: 3, wrong: 1),
      'PL010-0003': p('PL010-0003', correct: 0, wrong: 2),
      'PL010-0004': p('PL010-0004', correct: 1, wrong: 1),
    };
    final queue = buildPracticeQueue(
      mode: PracticeMode.learn,
      questions: questions,
      progress: progress,
      now: now,
    );
    expect(ids(queue), [
      'PL010-0002',
      'PL010-0005',
      'PL010-0003',
      'PL010-0004',
      'PL010-0001',
    ]);
  });

  test('a bookmarked but never answered question counts as not seen', () {
    final queue = buildPracticeQueue(
      mode: PracticeMode.learn,
      questions: questions,
      progress: {'PL010-0001': p('PL010-0001', bookmarked: true)},
      now: now,
    );
    expect(queue.first.id, 'PL010-0001');
  });

  test('review: only due questions, the oldest due first', () {
    final progress = {
      'PL010-0001': p(
        'PL010-0001',
        correct: 1,
        due: now.add(const Duration(days: 1)),
      ),
      'PL010-0002': p(
        'PL010-0002',
        correct: 1,
        due: now.subtract(const Duration(days: 1)),
      ),
      'PL010-0003': p('PL010-0003', correct: 1, due: now),
      'PL010-0004': p(
        'PL010-0004',
        correct: 1,
        due: now.subtract(const Duration(days: 3)),
      ),
    };
    final queue = buildPracticeQueue(
      mode: PracticeMode.review,
      questions: questions,
      progress: progress,
      now: now,
    );
    expect(ids(queue), ['PL010-0004', 'PL010-0002', 'PL010-0003']);
  });

  test('mistakes: wrong and fewer than two correct in a row', () {
    final progress = {
      'PL010-0001': p('PL010-0001', wrong: 1),
      'PL010-0002': p('PL010-0002', wrong: 1, correct: 1, consecutive: 1),
      'PL010-0003': p('PL010-0003', wrong: 1, correct: 2, consecutive: 2),
      'PL010-0004': p('PL010-0004', correct: 3, consecutive: 3),
    };
    final queue = buildPracticeQueue(
      mode: PracticeMode.mistakes,
      questions: questions,
      progress: progress,
      now: now,
    );
    expect(ids(queue), ['PL010-0001', 'PL010-0002']);
  });

  test('bookmarks and retry', () {
    final progress = {
      'PL010-0002': p('PL010-0002', bookmarked: true),
      'PL010-0005': p('PL010-0005', bookmarked: true),
    };
    expect(
      ids(
        buildPracticeQueue(
          mode: PracticeMode.bookmarks,
          questions: questions,
          progress: progress,
          now: now,
        ),
      ),
      ['PL010-0002', 'PL010-0005'],
    );
    expect(
      ids(
        buildPracticeQueue(
          mode: PracticeMode.retry,
          questions: questions,
          progress: progress,
          now: now,
          retryIds: ['PL010-0004', 'PL010-9999', 'PL010-0001'],
        ),
      ),
      ['PL010-0004', 'PL010-0001'],
    );
  });

  test('stats count coverage, accuracy, due, mistakes and bookmarks', () {
    final progress = {
      'PL010-0001': p(
        'PL010-0001',
        correct: 2,
        wrong: 1,
        consecutive: 0,
        due: now.subtract(const Duration(hours: 1)),
        bookmarked: true,
      ),
      'PL010-0002': p('PL010-0002', correct: 1, consecutive: 1, due: now),
      'PL010-0003': p('PL010-0003', bookmarked: true),
      'OTHER-0001': p('OTHER-0001', wrong: 5),
    };
    final stats = computeSubjectStats(questions, progress, now);
    expect(stats.total, 5);
    expect(stats.covered, 2);
    expect(stats.unseen, 3);
    expect(stats.correct, 3);
    expect(stats.wrong, 1);
    expect(stats.due, 2);
    expect(stats.mistakes, 1);
    expect(stats.bookmarks, 2);
    expect(stats.accuracy, closeTo(0.75, 1e-9));
  });

  test('empty progress gives zero stats without NaN', () {
    final stats = computeSubjectStats(const [], const {}, now);
    expect(stats.coverage, 0);
    expect(stats.accuracy, 0);
    expect(stats.hasAnswers, isFalse);
  });

  test('variants of one NUMER are not asked one after another', () {
    final withVariants = [
      q('PL010-0001~a', 'PL010-0001'),
      q('PL010-0001~b', 'PL010-0001'),
      q('PL010-0001~c', 'PL010-0001'),
      q('PL010-0002'),
      q('PL010-0003~a', 'PL010-0003'),
      q('PL010-0003~b', 'PL010-0003'),
      q('PL010-0004'),
    ];
    final queue = buildPracticeQueue(
      mode: PracticeMode.learn,
      questions: withVariants,
      progress: const {},
      now: now,
    );
    expect(queue, hasLength(7));
    expect(ids(queue).toSet(), ids(withVariants).toSet());
    for (var i = 1; i < queue.length; i++) {
      expect(queue[i].number, isNot(queue[i - 1].number));
    }
    // First variants come before the other ones.
    expect(ids(queue).take(4), [
      'PL010-0001~a',
      'PL010-0002',
      'PL010-0003~a',
      'PL010-0004',
    ]);
  });

  test('the examples of the review: [B, A1, A2] and a seam between parts', () {
    final a1 = q('PL010-0001~a', 'PL010-0001');
    final a2 = q('PL010-0001~b', 'PL010-0001');
    final b = q('PL010-0002');
    expect(ids(spreadVariants([b, a1, a2])), [
      'PL010-0001~a',
      'PL010-0002',
      'PL010-0001~b',
    ]);
    expect(ids(spreadVariants([a1, a2, b])), [
      'PL010-0001~a',
      'PL010-0002',
      'PL010-0001~b',
    ]);
    // [A1, B, C1, C2, A2]: only A1, C1, B, C2, A2 style orders work; the
    // earliest feasible choice is taken at every step.
    final c1 = q('PL010-0003~a', 'PL010-0003');
    final c2 = q('PL010-0003~b', 'PL010-0003');
    final out = spreadVariants([a1, b, c1, c2, a2]);
    for (var i = 1; i < out.length; i++) {
      expect(out[i].number, isNot(out[i - 1].number));
    }
    expect(ids(out).first, 'PL010-0001~a');
  });

  test('unavoidable neighbours are kept, nothing is lost', () {
    final only = [
      q('PL010-0090~a', 'PL010-0090'),
      q('PL010-0090~b', 'PL010-0090'),
      q('PL010-0090~c', 'PL010-0090'),
      q('PL010-0091'),
    ];
    final out = spreadVariants(only);
    expect(ids(out).toSet(), ids(only).toSet());
    expect(out, hasLength(4));
    expect(spreadVariants(const []), isEmpty);
  });

  test('canSpreadNumbers agrees with brute force', () {
    final random = Random(7);
    bool brute(List<String> items, String? last) {
      if (items.isEmpty) return true;
      for (var i = 0; i < items.length; i++) {
        if (items[i] == last) continue;
        final rest = [...items]..removeAt(i);
        if (brute(rest, items[i])) return true;
      }
      return false;
    }

    for (var t = 0; t < 400; t++) {
      final n = random.nextInt(8);
      final items = [for (var i = 0; i < n; i++) 'N${random.nextInt(4)}'];
      final last = random.nextBool() ? 'N${random.nextInt(4)}' : null;
      expect(
        canSpreadNumbers(items, last: last),
        brute(items, last),
        reason: '$items after $last',
      );
    }
  });

  test('spreading is a permutation, valid when possible and only shifts '
      'blocked questions', () {
    final random = Random(11);
    for (var t = 0; t < 300; t++) {
      final n = 1 + random.nextInt(12);
      final base = [
        for (var i = 0; i < n; i++)
          q('PL010-${(1000 + i)}', 'PL010-N${random.nextInt(5)}'),
      ];
      final out = spreadVariants(base);
      _expectSpread(base, out);
    }
  });

  group('real banks', () {
    final banks = <Licence, QuestionBank>{
      for (final l in Licence.values)
        l: parseBank(
          File('assets/data/${l.bankFileName}').readAsStringSync(),
          licence: l,
        ),
    };

    void forEachSubject(
      void Function(Licence l, SubjectId s, List<Question> all) body,
    ) {
      for (final bank in banks.values) {
        for (final subject in bank.subjects) {
          body(bank.licence, subject, bank.questionsOf(subject));
        }
      }
    }

    List<Question> learn(
      List<Question> all,
      Map<String, QuestionProgress> progress,
    ) => buildPracticeQueue(
      mode: PracticeMode.learn,
      questions: all,
      progress: progress,
      now: now,
    );

    QuestionProgress answered(Question x, int order, bool right) =>
        QuestionProgress(
          qid: x.id,
          seen: 1,
          correct: right ? 1 : 0,
          wrong: right ? 0 : 1,
          lastAnsweredAt: now.add(Duration(minutes: order)),
          dueAt: now,
        );

    /// Checks all invariants of a queue built from [progress].
    void checkQueue(
      String label,
      List<Question> all,
      Map<String, QuestionProgress> progress,
    ) {
      final queue = learn(all, progress);
      expect(
        ids(queue),
        ids(learn(all, progress)),
        reason: '$label determinism',
      );
      expect({...ids(queue)}, {...ids(all)}, reason: '$label same set');
      expect(queue, hasLength(all.length), reason: '$label once each');
      final priority = learnPriorityOrder(all, progress);
      // Priority order: fresh numbers, variants of touched numbers, seen.
      final touched = {
        for (final x in all)
          if ((progress[x.id]?.seen ?? 0) > 0) x.number,
      };
      int tier(Question x) => (progress[x.id]?.seen ?? 0) > 0
          ? 2
          : touched.contains(x.number)
          ? 1
          : 0;
      for (var i = 1; i < priority.length; i++) {
        expect(tier(priority[i]), greaterThanOrEqualTo(tier(priority[i - 1])));
      }
      final seen = [
        for (final x in priority)
          if (tier(x) == 2) progress[x.id]!,
      ];
      for (var i = 1; i < seen.length; i++) {
        expect(
          seen[i].correct / seen[i].seen,
          greaterThanOrEqualTo(seen[i - 1].correct / seen[i - 1].seen),
          reason: '$label accuracy order',
        );
      }
      // The queue is the priority order, spread over the whole queue.
      expect(ids(queue), ids(spreadVariants(priority)));
      _expectSpread(priority, queue);
    }

    test('empty progress', () {
      forEachSubject((l, s, all) => checkQueue('${l.id}/${s.id}', all, {}));
    });

    test('after answering the first k questions, rebuilding every block', () {
      forEachSubject((l, s, all) {
        final progress = <String, QuestionProgress>{};
        var count = 0;
        for (final k in [1, 5, 20, 100]) {
          final queue = learn(all, progress);
          final take = queue.take(k).toList();
          for (final x in take) {
            progress[x.id] = answered(x, count++, count.isEven);
          }
          final label = '${l.id}/${s.id} after $k';
          checkQueue(label, all, progress);
          final next = learn(all, progress);
          final answeredNumbers = {for (final x in take) x.number};
          final touched = {
            for (final x in all)
              if (progress.containsKey(x.id)) x.number,
          };
          final freshLeft = [
            for (final x in all)
              if (!progress.containsKey(x.id) && !touched.contains(x.number)) x,
          ].length;
          final window = k < freshLeft ? k : freshLeft;
          for (var i = 0; i < window; i++) {
            expect(
              answeredNumbers.contains(next[i].number),
              isFalse,
              reason: '$label position $i is a variant of an answered NUMER',
            );
          }
        }
      });
    });

    test('random partial progress (several seeds)', () {
      for (final seed in [1, 2, 3, 4, 5]) {
        final random = Random(seed);
        forEachSubject((l, s, all) {
          final progress = <String, QuestionProgress>{};
          var order = 0;
          for (final x in all) {
            if (random.nextDouble() < 0.3) {
              final seenCount = 1 + random.nextInt(3);
              final correct = random.nextInt(seenCount + 1);
              progress[x.id] = QuestionProgress(
                qid: x.id,
                seen: seenCount,
                correct: correct,
                wrong: seenCount - correct,
                lastAnsweredAt: now.add(Duration(minutes: order++)),
              );
            }
          }
          checkQueue('seed $seed ${l.id}/${s.id}', all, progress);
        });
      }
    });
  });
}

/// [out] must be a permutation of [base]; no equal NUMER neighbours when that
/// is possible; and a question is passed over only when it would repeat the
/// previous NUMER or when taking it would make a spread impossible.
void _expectSpread(List<Question> base, List<Question> out) {
  expect(out, hasLength(base.length));
  expect({...ids(out)}, {...ids(base)});
  final possible = canSpreadNumbers([for (final x in base) x.number]);
  if (possible) {
    for (var i = 1; i < out.length; i++) {
      expect(out[i].number, isNot(out[i - 1].number), reason: 'at $i');
    }
    final remaining = [...base];
    String? previous;
    for (final placed in out) {
      final index = remaining.indexWhere((x) => x.id == placed.id);
      for (var j = 0; j < index; j++) {
        final r = remaining[j];
        if (r.number == previous) continue;
        final rest = [...remaining]..removeAt(j);
        expect(
          canSpreadNumbers([for (final x in rest) x.number], last: r.number),
          isFalse,
          reason: '${r.id} was passed over without a reason',
        );
      }
      remaining.removeAt(index);
      previous = placed.number;
    }
  }
}
