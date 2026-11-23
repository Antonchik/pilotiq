import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pilotiq/src/domain/readiness.dart';

double _choose(int n, int k) {
  var r = 1.0;
  for (var i = 1; i <= k; i++) {
    r = r * (n - k + i) / i;
  }
  return r;
}

void main() {
  test('p = 1 gives about 1, p = 0 gives 0', () {
    expect(ReadinessCalculator.passProbability(n: 12, p: 1), closeTo(1, 1e-9));
    expect(ReadinessCalculator.passProbability(n: 12, p: 0), 0);
  });

  test('N=12, p=0.75 matches the explicit binomial sum', () {
    var expected = 0.0;
    for (var i = 9; i <= 12; i++) {
      expected += _choose(12, i) * math.pow(0.75, i) * math.pow(0.25, 12 - i);
    }
    expect(
      ReadinessCalculator.passProbability(n: 12, p: 0.75),
      closeTo(expected, 1e-6),
    );
  });

  test('threshold is ceil(0.75 * N), e.g. 21 of 28', () {
    var expected = 0.0;
    for (var i = 21; i <= 28; i++) {
      expected += _choose(28, i) * math.pow(0.8, i) * math.pow(0.2, 28 - i);
    }
    expect(
      ReadinessCalculator.passProbability(n: 28, p: 0.8),
      closeTo(expected, 1e-6),
    );
  });

  test('no data gives a defined value strictly between 0 and 1', () {
    final r = ReadinessCalculator.subjectReadiness(
      recentByQuestion: const [],
      bankSize: 300,
      quizLength: 12,
    );
    expect(r.isNaN, isFalse);
    expect(r, greaterThan(0));
    expect(r, lessThan(1));
  });

  test('empty bank or zero quiz length gives 0, never NaN', () {
    expect(
      ReadinessCalculator.subjectReadiness(
        recentByQuestion: const [],
        bankSize: 0,
        quizLength: 12,
      ),
      0,
    );
    expect(ReadinessCalculator.passProbability(n: 0, p: 0.5), 0);
  });

  test('estimateP weighs fresh answers more and the uncovered part by prior', () {
    // two answers: wrong then correct -> weights 3 (newest, correct), 2 (wrong)
    final acc = ReadinessCalculator.seenAccuracy([
      [false, true],
    ]);
    expect(acc, closeTo(3 / 5, 1e-12));
    // full coverage: p equals accuracy
    expect(
      ReadinessCalculator.estimateP(
        recentByQuestion: [
          [true],
          [true],
        ],
        bankSize: 2,
      ),
      closeTo(1, 1e-12),
    );
    // half coverage with perfect accuracy: 0.5*1 + 0.5*0.5
    expect(
      ReadinessCalculator.estimateP(
        recentByQuestion: [
          [true],
        ],
        bankSize: 2,
      ),
      closeTo(0.75, 1e-12),
    );
  });

  test('a well-known subject is more ready than an unknown one', () {
    final strong = ReadinessCalculator.subjectReadiness(
      recentByQuestion: List.generate(100, (_) => [true, true, true]),
      bankSize: 100,
      quizLength: 12,
    );
    final unknown = ReadinessCalculator.subjectReadiness(
      recentByQuestion: const [],
      bankSize: 100,
      quizLength: 12,
    );
    expect(strong, greaterThan(unknown));
    expect(strong, closeTo(1, 1e-9));
  });
}
