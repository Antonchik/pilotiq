import 'package:flutter_test/flutter_test.dart';
import 'package:pilotiq/src/domain/leitner.dart';
import 'package:pilotiq/src/domain/mistakes.dart';
import 'package:pilotiq/src/progress/question_progress.dart';

void main() {
  const scheduler = LeitnerScheduler();
  final now = DateTime(2026, 5, 1, 12);

  test('correct answers climb 1..5 and stop at 5', () {
    var p = const QuestionProgress(qid: 'q');
    final boxes = <int>[];
    for (var i = 0; i < 6; i++) {
      p = scheduler.answer(p, correct: true, now: now);
      boxes.add(p.box);
    }
    expect(boxes, [2, 3, 4, 5, 5, 5]);
    expect(p.correct, 6);
    expect(p.consecutiveCorrect, 6);
    expect(p.seen, 6);
  });

  test('wrong answer from box 4 returns to box 1', () {
    final p = scheduler.answer(
      const QuestionProgress(qid: 'q', box: 4, consecutiveCorrect: 3),
      correct: false,
      now: now,
    );
    expect(p.box, 1);
    expect(p.consecutiveCorrect, 0);
    expect(p.wrong, 1);
    expect(p.dueAt, DateTime(2026, 5, 2, 12));
  });

  test('intervals are 1/2/4/8/16 days', () {
    expect(
      [for (var b = 1; b <= 5; b++) scheduler.intervalDays(b, now: now)],
      [1, 2, 4, 8, 16],
    );
    var p = const QuestionProgress(qid: 'q');
    final days = <int>[];
    for (var i = 0; i < 5; i++) {
      p = scheduler.answer(p, correct: true, now: now);
      days.add(p.dueAt!.difference(now).inDays);
    }
    expect(days, [2, 4, 8, 16, 16]);
  });

  test('exam date caps the interval at half of the remaining days', () {
    expect(
      scheduler.intervalDays(5, now: now, examDate: DateTime(2026, 5, 7)),
      3,
    );
    expect(
      scheduler.intervalDays(5, now: now, examDate: DateTime(2026, 5, 2)),
      1,
    );
    expect(
      scheduler.intervalDays(5, now: now, examDate: DateTime(2026, 5, 1)),
      1,
    );
    // exam far away: no effect
    expect(
      scheduler.intervalDays(3, now: now, examDate: DateTime(2026, 9, 1)),
      4,
    );
  });

  test('exam date in the past does not cap', () {
    expect(
      scheduler.intervalDays(5, now: now, examDate: DateTime(2026, 4, 1)),
      16,
    );
  });

  test('answer with an exam date in the past is not capped', () {
    final p = scheduler.answer(
      const QuestionProgress(qid: 'q', box: 4),
      correct: true,
      now: now,
      examDate: DateTime(2026, 4, 1),
    );
    expect(p.dueAt, DateTime(2026, 5, 17, 12));
  });

  test('answer applies the cap to dueAt', () {
    final p = scheduler.answer(
      const QuestionProgress(qid: 'q', box: 4),
      correct: true,
      now: now,
      examDate: DateTime(2026, 5, 7),
    );
    expect(p.box, 5);
    expect(p.dueAt, DateTime(2026, 5, 4, 12));
  });

  test('recent keeps only the last three answers', () {
    var p = const QuestionProgress(qid: 'q');
    for (final c in [true, false, true, true]) {
      p = scheduler.answer(p, correct: c, now: now);
    }
    expect(p.recent, [false, true, true]);
  });

  group('mistakes', () {
    test('wrong=1, consecutiveCorrect=1 is a mistake', () {
      expect(
        isMistake(
          const QuestionProgress(qid: 'q', wrong: 1, consecutiveCorrect: 1),
        ),
        isTrue,
      );
    });
    test('consecutiveCorrect=2 is not a mistake', () {
      expect(
        isMistake(
          const QuestionProgress(qid: 'q', wrong: 1, consecutiveCorrect: 2),
        ),
        isFalse,
      );
    });
    test('never wrong is not a mistake', () {
      expect(isMistake(const QuestionProgress(qid: 'q', correct: 3)), isFalse);
    });
    test('mistakeIds filters', () {
      expect(
        mistakeIds(const [
          QuestionProgress(qid: 'a', wrong: 1),
          QuestionProgress(qid: 'b'),
        ]),
        ['a'],
      );
    });
  });
}
