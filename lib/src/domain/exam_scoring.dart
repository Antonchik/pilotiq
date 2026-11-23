/// A question of an attempt as the scorer sees it. [correctIndex] and the
/// attempt's answers both use the canonical bank order of the answers.
class ScoredQuestion {
  const ScoredQuestion({
    required this.qid,
    required this.topic,
    required this.correctIndex,
  });

  final String qid;
  final String topic;
  final int correctIndex;
}

class TopicScore {
  const TopicScore({required this.total, required this.correct});

  final int total;
  final int correct;

  Map<String, dynamic> toMap() => {'total': total, 'correct': correct};

  factory TopicScore.fromMap(Map<dynamic, dynamic> m) => TopicScore(
    total: (m['total'] as num?)?.toInt() ?? 0,
    correct: (m['correct'] as num?)?.toInt() ?? 0,
  );

  @override
  bool operator ==(Object other) =>
      other is TopicScore && other.total == total && other.correct == correct;

  @override
  int get hashCode => Object.hash(total, correct);

  @override
  String toString() => 'TopicScore($correct/$total)';
}

class ExamScore {
  const ExamScore({
    required this.total,
    required this.correct,
    required this.answered,
    required this.passed,
    required this.topicBreakdown,
  });

  final int total;
  final int correct;
  final int answered;
  final bool passed;
  final Map<String, TopicScore> topicBreakdown;

  int get unanswered => total - answered;

  /// Share of correct answers among **all** questions, 0..1.
  double get ratio => total == 0 ? 0 : correct / total;

  /// [ratio] in percent, 0..100.
  double get percent => ratio * 100;
}

class ExamScoring {
  const ExamScoring._();

  /// Scores an attempt. The denominator is the number of all questions; an
  /// unanswered question counts as wrong. [answers] maps qid to the chosen
  /// index or null.
  static ExamScore score(
    List<ScoredQuestion> questions,
    Map<String, int?> answers, {
    double passRatio = 0.75,
  }) {
    var correct = 0;
    var answered = 0;
    final totals = <String, int>{};
    final corrects = <String, int>{};
    for (final q in questions) {
      final a = answers[q.qid];
      totals[q.topic] = (totals[q.topic] ?? 0) + 1;
      if (a != null) answered++;
      if (a != null && a == q.correctIndex) {
        correct++;
        corrects[q.topic] = (corrects[q.topic] ?? 0) + 1;
      }
    }
    final total = questions.length;
    final passed = total > 0 && correct / total >= passRatio - 1e-9;
    return ExamScore(
      total: total,
      correct: correct,
      answered: answered,
      passed: passed,
      topicBreakdown: {
        for (final t in totals.keys)
          t: TopicScore(total: totals[t]!, correct: corrects[t] ?? 0),
      },
    );
  }
}
