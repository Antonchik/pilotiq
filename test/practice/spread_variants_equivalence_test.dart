import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilotiq/src/bank/models.dart';
import 'package:pilotiq/src/bank/question_bank_repository.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/quiz/practice/practice_session.dart';

/// The previous implementation of `spreadVariants` (every candidate re-checked
/// against all numbers), kept here as the reference: the faster version must
/// give exactly the same order.
List<Question> _referenceSpread(List<Question> questions) {
  bool canSpread(Map<String, int> counts, int n, String? last) {
    for (final e in counts.entries) {
      if (e.value == 0) continue;
      final limit = e.key == last ? n ~/ 2 : (n + 1) ~/ 2;
      if (e.value > limit) return false;
    }
    return true;
  }

  final rest = <Question>[...questions];
  final counts = <String, int>{};
  for (final q in rest) {
    counts[q.number] = (counts[q.number] ?? 0) + 1;
  }
  final result = <Question>[];
  var possible = canSpread(counts, rest.length, null);
  while (rest.isNotEmpty) {
    final last = result.isEmpty ? null : result.last.number;
    var pick = -1;
    var firstOther = -1;
    for (var i = 0; i < rest.length; i++) {
      final number = rest[i].number;
      if (number == last) continue;
      if (firstOther < 0) firstOther = i;
      if (!possible) break;
      counts[number] = counts[number]! - 1;
      final ok = canSpread(counts, rest.length - 1, number);
      counts[number] = counts[number]! + 1;
      if (ok) {
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

Question _q(int i, String number) => Question(
  id: 'PL010-${1000 + i}',
  number: number,
  topic: 'PL010',
  subject: SubjectId.airLaw,
  text: LocalizedText(pl: 'q$i'),
  answers: [for (var k = 0; k < 4; k++) LocalizedText(pl: 'a$k')],
  correctIndex: 0,
);

List<String> _ids(List<Question> l) => [for (final x in l) x.id];

void main() {
  test('same order as the reference on every subject of every licence', () {
    final random = Random(5);
    for (final licence in Licence.values) {
      final bank = parseBank(
        File('assets/data/${licence.bankFileName}').readAsStringSync(),
        licence: licence,
      );
      for (final subject in bank.subjects) {
        final all = bank.questionsOf(subject);
        final lists = [
          all,
          all.reversed.toList(),
          for (var k = 0; k < 4; k++) [...all]..shuffle(random),
          // a bank-like list with the variants of a number next to each other
          [...all]..sort((a, b) => a.number.compareTo(b.number)),
        ];
        for (final list in lists) {
          expect(
            _ids(spreadVariants(list)),
            _ids(_referenceSpread(list)),
            reason: '${licence.id} ${subject.id}',
          );
        }
      }
    }
  });

  test('same order as the reference on random lists, spreadable or not', () {
    final random = Random(99);
    for (var t = 0; t < 1500; t++) {
      final n = random.nextInt(40);
      final distinct = 1 + random.nextInt(8);
      final list = [
        for (var i = 0; i < n; i++) _q(i, 'N${random.nextInt(distinct)}'),
      ];
      expect(_ids(spreadVariants(list)), _ids(_referenceSpread(list)));
    }
  });

  test('a large degenerate list is handled quickly (no cubic cost)', () {
    // Many different numbers and a spread that is impossible (one number is
    // more than half of the list): the old version tried every candidate
    // against every number at every step.
    const n = 3000;
    final list = [
      for (var i = 0; i < n; i++) _q(i, i < n * 0.7 ? 'BIG' : 'N$i'),
    ];
    final watch = Stopwatch()..start();
    final out = spreadVariants(list);
    watch.stop();
    expect(out, hasLength(n));
    expect({..._ids(out)}, {..._ids(list)});
    expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
  });
}
