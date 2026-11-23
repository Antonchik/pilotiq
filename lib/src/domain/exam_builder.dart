import 'dart:math';

import 'package:pilotiq/src/domain/catalog.dart';

/// What the exam builder needs to know about a question.
class ExamCandidate {
  const ExamCandidate({
    required this.id,
    required this.number,
    required this.topic,
  });

  final String id;

  /// Normalised NUMER; variants of one question share it.
  final String number;

  /// Topic prefix, e.g. `PL010`.
  final String topic;
}

/// Builds a random exam sample of one subject.
class ExamBuilder {
  const ExamBuilder._();

  /// Picks `spec.quizLength` questions without repeats, at most one variant per
  /// `number`, stratified by `topic` in proportion to topic size (largest
  /// remainder). If the bank has fewer distinct numbers, all of them are used.
  /// The result is deterministic for a given [random] seed and input set.
  static List<ExamCandidate> build(
    List<ExamCandidate> subjectQuestions,
    ExamSpec spec,
    Random random,
  ) {
    final byNumber = <String, List<ExamCandidate>>{};
    for (final q in subjectQuestions) {
      byNumber.putIfAbsent(q.number, () => []).add(q);
    }
    final numbers = byNumber.keys.toList()..sort();
    final unique = <ExamCandidate>[];
    for (final number in numbers) {
      final variants = byNumber[number]!..sort((a, b) => a.id.compareTo(b.id));
      unique.add(variants[random.nextInt(variants.length)]);
    }

    final n = spec.quizLength;
    if (unique.length <= n) {
      return unique..shuffle(random);
    }

    final byTopic = <String, List<ExamCandidate>>{};
    for (final q in unique) {
      byTopic.putIfAbsent(q.topic, () => []).add(q);
    }
    final topics = byTopic.keys.toList()..sort();
    final total = unique.length;

    final quota = <String, int>{};
    final remainder = <String, double>{};
    var assigned = 0;
    for (final t in topics) {
      final exact = n * byTopic[t]!.length / total;
      quota[t] = exact.floor();
      remainder[t] = exact - exact.floor();
      assigned += quota[t]!;
    }
    final order = [...topics]
      ..sort((a, b) {
        final c = remainder[b]!.compareTo(remainder[a]!);
        if (c != 0) return c;
        final s = byTopic[b]!.length.compareTo(byTopic[a]!.length);
        return s != 0 ? s : a.compareTo(b);
      });
    for (var i = 0; assigned < n; i = (i + 1) % order.length) {
      final t = order[i];
      if (quota[t]! < byTopic[t]!.length) {
        quota[t] = quota[t]! + 1;
        assigned++;
      }
    }

    final picked = <ExamCandidate>[];
    for (final t in topics) {
      final group = [...byTopic[t]!]..shuffle(random);
      picked.addAll(group.take(quota[t]!));
    }
    return picked..shuffle(random);
  }
}
