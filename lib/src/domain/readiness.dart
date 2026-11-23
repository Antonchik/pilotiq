import 'dart:math' as math;

/// Rough estimate of the chance to pass a subject exam. Not a promise: the UI
/// labels it "approximate".
class ReadinessCalculator {
  const ReadinessCalculator._();

  /// Weights of the recent answers of one question, newest first.
  static const List<double> recentWeights = [3, 2, 1];

  /// Prior probability of a correct answer on a question never seen.
  static const double prior = 0.5;

  /// P(Binomial(n, p) >= ceil(passRatio * n)). Returns 0 for n <= 0.
  static double passProbability({
    required int n,
    required double p,
    double passRatio = 0.75,
  }) {
    if (n <= 0) return 0;
    final k = (passRatio * n - 1e-9).ceil();
    if (k <= 0) return 1;
    if (k > n) return 0;
    if (p <= 0) return 0;
    if (p >= 1) return 1;
    var sum = 0.0;
    for (var i = k; i <= n; i++) {
      sum += math.exp(
        _logChoose(n, i) + i * math.log(p) + (n - i) * math.log(1 - p),
      );
    }
    return sum.clamp(0.0, 1.0);
  }

  static double _logChoose(int n, int k) {
    var r = 0.0;
    for (var i = 1; i <= k; i++) {
      r += math.log(n - k + i) - math.log(i);
    }
    return r;
  }

  /// Accuracy over seen questions. Each entry holds the last answers of one
  /// question (oldest first, correct = true); fresher answers weigh more.
  /// Returns null when nothing has been answered.
  static double? seenAccuracy(Iterable<List<bool>> recentByQuestion) {
    var total = 0.0;
    var count = 0;
    for (final recent in recentByQuestion) {
      if (recent.isEmpty) continue;
      var num = 0.0;
      var den = 0.0;
      for (var i = 0; i < recent.length && i < recentWeights.length; i++) {
        final w = recentWeights[i];
        final answer = recent[recent.length - 1 - i];
        den += w;
        if (answer) num += w;
      }
      total += num / den;
      count++;
    }
    return count == 0 ? null : total / count;
  }

  /// Estimated probability of a correct answer on a random question of the
  /// subject: seen questions by their accuracy, the uncovered part of the bank
  /// by [prior], weighted by coverage.
  static double estimateP({
    required Iterable<List<bool>> recentByQuestion,
    required int bankSize,
  }) {
    final list = recentByQuestion.where((r) => r.isNotEmpty).toList();
    final acc = seenAccuracy(list);
    if (acc == null || bankSize <= 0) return prior;
    final coverage = (list.length / bankSize).clamp(0.0, 1.0);
    return coverage * acc + (1 - coverage) * prior;
  }

  /// Readiness of a subject: chance to pass a [quizLength]-question exam.
  static double subjectReadiness({
    required Iterable<List<bool>> recentByQuestion,
    required int bankSize,
    required int quizLength,
    double passRatio = 0.75,
  }) {
    if (bankSize <= 0 || quizLength <= 0) return 0;
    final p = estimateP(recentByQuestion: recentByQuestion, bankSize: bankSize);
    return passProbability(n: quizLength, p: p, passRatio: passRatio);
  }
}
