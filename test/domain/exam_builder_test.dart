import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/domain/exam_builder.dart';

List<ExamCandidate> _bank(Map<String, int> perTopic, {int variantsEvery = 0}) {
  final out = <ExamCandidate>[];
  perTopic.forEach((topic, count) {
    for (var i = 0; i < count; i++) {
      final number = '$topic-${i.toString().padLeft(4, '0')}';
      out.add(ExamCandidate(id: number, number: number, topic: topic));
      if (variantsEvery > 0 && i % variantsEvery == 0) {
        out.add(
          ExamCandidate(id: '$number~abc123', number: number, topic: topic),
        );
      }
    }
  });
  return out;
}

void main() {
  const spec = ExamSpec(quizLength: 28, minutes: 45);

  test('same seed gives the same exam', () {
    final bank = _bank({'PL010': 50, 'PL099': 30, 'PL100': 20});
    final a = ExamBuilder.build(
      bank,
      spec,
      Random(7),
    ).map((q) => q.id).toList();
    final b = ExamBuilder.build(
      bank,
      spec,
      Random(7),
    ).map((q) => q.id).toList();
    final c = ExamBuilder.build(
      bank,
      spec,
      Random(8),
    ).map((q) => q.id).toList();
    expect(a, b);
    expect(a, isNot(c));
  });

  test('size is N, ids and numbers are unique', () {
    final bank = _bank({
      'PL010': 50,
      'PL099': 30,
      'PL100': 20,
    }, variantsEvery: 2);
    final exam = ExamBuilder.build(bank, spec, Random(1));
    expect(exam.length, 28);
    expect(exam.map((q) => q.id).toSet().length, 28);
    expect(exam.map((q) => q.number).toSet().length, 28);
  });

  test('variants of one NUMER never meet in one exam (many seeds)', () {
    // every number has 3 variants and the bank is just above N
    final bank = <ExamCandidate>[];
    for (var i = 0; i < 30; i++) {
      for (final v in ['', '~aaaaaa', '~bbbbbb']) {
        final n = 'PL010-${i.toString().padLeft(4, '0')}';
        bank.add(ExamCandidate(id: '$n$v', number: n, topic: 'PL010'));
      }
    }
    for (var seed = 0; seed < 50; seed++) {
      final exam = ExamBuilder.build(bank, spec, Random(seed));
      expect(exam.map((q) => q.number).toSet().length, exam.length);
      expect(exam.length, 28);
    }
  });

  test('topic shares differ from the proportion by less than 1', () {
    final sizes = {'PL010': 53, 'PL099': 31, 'PL100': 17, 'PL102': 9};
    final total = sizes.values.reduce((a, b) => a + b);
    for (var seed = 0; seed < 20; seed++) {
      final exam = ExamBuilder.build(_bank(sizes), spec, Random(seed));
      for (final e in sizes.entries) {
        final got = exam.where((q) => q.topic == e.key).length;
        expect(
          (got - 28 * e.value / total).abs(),
          lessThan(1),
          reason: '${e.key} seed $seed',
        );
      }
    }
  });

  test('bank smaller than N returns everything (one variant per NUMER)', () {
    final bank = _bank({'PL010': 5, 'PL099': 4}, variantsEvery: 1);
    final exam = ExamBuilder.build(bank, spec, Random(3));
    expect(exam.length, 9);
    expect(exam.map((q) => q.number).toSet().length, 9);
  });

  test('bank exactly N returns all questions', () {
    final exam = ExamBuilder.build(
      _bank({'PL010': 20, 'PL099': 8}),
      spec,
      Random(3),
    );
    expect(exam.length, 28);
  });

  test('empty bank gives an empty exam', () {
    expect(ExamBuilder.build(const [], spec, Random(1)), isEmpty);
  });

  test('result does not depend on input order', () {
    final bank = _bank({'PL010': 40, 'PL099': 20}, variantsEvery: 3);
    final reversed = bank.reversed.toList();
    final a = ExamBuilder.build(
      bank,
      spec,
      Random(5),
    ).map((q) => q.id).toList();
    final b = ExamBuilder.build(
      reversed,
      spec,
      Random(5),
    ).map((q) => q.id).toList();
    expect(a, b);
  });
}
