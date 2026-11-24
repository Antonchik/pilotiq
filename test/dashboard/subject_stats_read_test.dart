import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pilotiq/src/bank/question_bank_repository.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/progress/progress_repository.dart';
import 'package:pilotiq/src/progress/providers.dart';
import 'package:pilotiq/src/quiz/practice/practice_controller.dart';

import '../bank/fake_bank.dart';
import '../bank/memory_hive.dart';

/// Counts the passes over the whole box.
class _CountingBox implements Box<dynamic> {
  _CountingBox(this.inner, this.counter);
  final Box<dynamic> inner;
  final List<String> counter;

  @override
  Iterable<dynamic> get values {
    counter.add(inner.name);
    return inner.values;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  test('B2: the stats of all subjects read the progress box once', () async {
    final reads = <String>[];
    final repo = ProgressRepository(
      openBox: (name) async {
        final box = await openMemoryBox(name);
        return name == 'progress_ppla' ? _CountingBox(box, reads) : box;
      },
    );
    final container = ProviderContainer(
      overrides: [
        progressRepositoryProvider.overrideWithValue(repo),
        questionBankRepositoryProvider.overrideWithValue(fakeBankRepository()),
        clockProvider.overrideWithValue(Clock.fixed(DateTime(2026, 11, 23))),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await Hive.close();
    });
    final bank = await container.read(bankProvider(Licence.ppla).future);
    reads.clear();

    await Future.wait([
      for (final id in bank.subjects)
        container.read(
          subjectStatsProvider((licence: Licence.ppla, subject: id)).future,
        ),
    ]);

    expect(bank.subjects.length, greaterThan(1));
    expect(reads, hasLength(1));
  });
}
