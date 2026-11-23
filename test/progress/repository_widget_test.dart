import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/progress/exam_attempt.dart';
import 'package:pilotiq/src/progress/progress_repository.dart';

// Several testWidgets in one file, each with its own Hive boxes: the write
// queue must not leak between tests (it used to hang the second test).
void main() {
  Future<void> scenario(WidgetTester tester, String id) async {
    late Directory dir;
    late ProgressRepository repo;
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('progress_widget_');
      Hive.init(dir.path);
      repo = ProgressRepository();
    });
    await tester.pumpWidget(const MaterialApp(home: Text('x')));

    final now = DateTime(2026, 5, 1, 12);
    await tester.runAsync(() async {
      await repo.recordAnswer(Licence.ppla, 'q', true, now);
      await repo.saveAttempt(
        ExamAttempt(
          id: id,
          licence: Licence.ppla,
          subject: SubjectId.airLaw,
          startedAt: now,
          finishedAt: now,
          durationSec: 1,
          total: 1,
          correct: 1,
          passed: true,
          reason: AttemptReason.finished,
        ),
      );
      await repo.toggleBookmark(Licence.ppla, 'q');
      expect((await repo.dailyStat(now)).answered, 1);
      expect(await repo.attempts(Licence.ppla), hasLength(1));
      await Hive.close();
      await dir.delete(recursive: true);
    });
  }

  testWidgets('first widget test writes progress', (tester) async {
    await scenario(tester, 'a');
  });

  testWidgets('second widget test in the same file does not hang', (
    tester,
  ) async {
    await scenario(tester, 'b');
  });

  testWidgets('and a third one', (tester) async {
    await scenario(tester, 'c');
  });
}
