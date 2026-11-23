import 'package:flutter_test/flutter_test.dart';
import 'package:pilotiq/src/domain/exam_scoring.dart';

List<ScoredQuestion> _qs(int n) => [
  for (var i = 0; i < n; i++)
    ScoredQuestion(
      qid: 'q$i',
      topic: i.isEven ? 'PL010' : 'PL099',
      correctIndex: 0,
    ),
];

void main() {
  test('no questions gives 0 percent, not passed, no NaN', () {
    final s = ExamScoring.score(const [], const {});
    expect(s.percent, 0);
    expect(s.ratio.isNaN, isFalse);
    expect(s.passed, isFalse);
  });

  test('no answers gives 0 percent and not passed', () {
    final s = ExamScoring.score(_qs(12), const {});
    expect(s.correct, 0);
    expect(s.percent, 0);
    expect(s.passed, isFalse);
    expect(s.unanswered, 12);
  });

  test('9 of 12 passes', () {
    final answers = {for (var i = 0; i < 9; i++) 'q$i': 0};
    final s = ExamScoring.score(_qs(12), answers);
    expect(s.passed, isTrue);
    expect(s.percent, 75);
  });

  test('8 of 12 does not pass', () {
    final answers = {for (var i = 0; i < 8; i++) 'q$i': 0};
    expect(ExamScoring.score(_qs(12), answers).passed, isFalse);
  });

  test('unanswered counts as wrong, denominator is all questions', () {
    final answers = <String, int?>{
      for (var i = 0; i < 9; i++) 'q$i': 0,
      'q9': null,
    };
    final s = ExamScoring.score(_qs(12), answers);
    expect(s.total, 12);
    expect(s.answered, 9);
    expect(s.correct, 9);
    // 8 correct of 12 with the rest blank: threshold is on all questions
    final s2 = ExamScoring.score(_qs(12), {
      for (var i = 0; i < 8; i++) 'q$i': 0,
    });
    expect(s2.passed, isFalse);
  });

  test('wrong index is not counted', () {
    final s = ExamScoring.score(_qs(4), {'q0': 1, 'q1': 0});
    expect(s.correct, 1);
    expect(s.answered, 2);
  });

  test('topic breakdown', () {
    final s = ExamScoring.score(_qs(4), {'q0': 0, 'q1': 0, 'q2': 1});
    expect(s.topicBreakdown['PL010'], const TopicScore(total: 2, correct: 1));
    expect(s.topicBreakdown['PL099'], const TopicScore(total: 2, correct: 1));
  });
}
