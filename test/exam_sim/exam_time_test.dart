import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilotiq/src/progress/exam_attempt.dart';
import 'package:pilotiq/src/domain/catalog.dart';

import 'exam_helpers.dart';

/// The exam clock under changes of the device clock and time zone. Moments
/// are given as UTC instants, so the tests mean the same under any TZ; run
/// them with TZ=UTC, Europe/Warsaw and America/Los_Angeles.
void main() {
  late ExamHarness h;

  setUp(() async {
    h = ExamHarness();
    await h.setUp();
  });

  tearDown(() => h.tearDown());

  Future<void> leave(WidgetTester tester) async {
    await tester.pageBack();
    await settle(tester);
    await tester.tap(find.byKey(const Key('exam_leave_confirm')));
    await settle(tester);
  }

  group('the clock is set back', () {
    testWidgets('by a day during the exam: never more than the duration', (
      tester,
    ) async {
      await h.pump(tester);
      await h.open(tester);
      await h.start(tester);
      await h.advance(tester, const Duration(minutes: 5));
      expect(find.text('25:00'), findsOneWidget);

      await h.advance(tester, const Duration(days: -1));

      expect(find.text('30:00'), findsOneWidget);
      expect(find.textContaining('24:'), findsNothing);
      // The new start was stored: after a restart the same holds.
      final saved = (await h.unfinished())!;
      expect(saved.remaining(h.now), const Duration(minutes: 30));
    });

    testWidgets('by an hour during the exam', (tester) async {
      await h.pump(tester);
      await h.open(tester);
      await h.start(tester);
      await h.advance(tester, const Duration(minutes: 20));
      await h.advance(tester, const Duration(hours: -1));

      expect(find.text('30:00'), findsOneWidget);
      await h.advance(tester, const Duration(minutes: 1));
      expect(find.text('29:00'), findsOneWidget);
    });

    testWidgets('between killing and restoring the app', (tester) async {
      await h.pump(tester);
      await h.open(tester);
      await h.start(tester);
      await h.advance(tester, const Duration(minutes: 10));
      await leave(tester);

      h.now = h.now.subtract(const Duration(days: 1));
      await h.open(tester);
      expect(find.textContaining('30 minutes left'), findsOneWidget);
      await tester.tap(find.byKey(const Key('exam_resume')));
      await settle(tester);

      expect(find.text('30:00'), findsOneWidget);
    });

    testWidgets('by an hour between killing and restoring (inside the '
        'exam): the exam does not get longer than its duration', (
      tester,
    ) async {
      await h.pump(tester);
      await h.open(tester);
      await h.start(tester);
      await h.advance(tester, const Duration(minutes: 5));
      await leave(tester);

      h.now = h.now.subtract(const Duration(minutes: 40));
      await h.open(tester);
      await tester.tap(find.byKey(const Key('exam_resume')));
      await settle(tester);

      expect(find.text('30:00'), findsOneWidget);
    });
  });

  group('time zones and daylight saving time', () {
    testWidgets('an attempt started in the second 02:40 of 25.10.2026 '
        '(Warsaw) is not shifted by an hour', (tester) async {
      h.now = DateTime.utc(2026, 10, 25, 1, 40);
      await h.pump(tester);
      await h.open(tester);
      await h.start(tester);
      await h.advance(tester, const Duration(minutes: 10));
      await leave(tester);

      await h.advance(tester, const Duration(minutes: 5));
      await h.open(tester);

      expect(find.textContaining('15 minutes left'), findsOneWidget);
      expect(await h.attempts(), isEmpty);
      await tester.tap(find.byKey(const Key('exam_resume')));
      await settle(tester);
      expect(find.text('15:00'), findsOneWidget);
    });

    testWidgets('an attempt through the night of 29.03.2026 keeps real '
        'elapsed time', (tester) async {
      h.now = DateTime.utc(2026, 3, 28, 23, 50);
      await h.pump(tester);
      await h.open(tester);
      await h.start(tester);
      await leave(tester);

      h.now = DateTime.utc(2026, 3, 29, 0, 10);
      await h.open(tester);

      expect(find.textContaining('10 of 12'), findsNothing);
      expect(find.textContaining('10 minutes left'), findsOneWidget);
    });
  });

  group('stored moments', () {
    InProgressAttempt attempt(DateTime start) => InProgressAttempt(
      id: 'a',
      licence: Licence.ppla,
      subject: SubjectId.communications,
      startedAt: start,
      durationSec: 1800,
      questionIds: const ['x'],
    );

    test('are stored as UTC and read as the same instant in any zone', () {
      final start = DateTime.utc(2026, 10, 25, 1, 40);
      final map = attempt(start.toLocal()).toMap();
      expect(map['startedAt'], '2026-10-25T01:40:00.000Z');
      final back = InProgressAttempt.tryFromMap(map)!;
      expect(back.startedAt.isAtSameMomentAs(start), isTrue);
      // 20 minutes later, remaining is 10 minutes whatever the zone.
      expect(
        back.remaining(start.add(const Duration(minutes: 20))),
        const Duration(minutes: 10),
      );
    });

    test('old records without an offset are read as local time', () {
      final map = attempt(DateTime(2026, 5, 1, 12)).toMap()
        ..['startedAt'] = '2026-05-01T12:00:00.000';
      final back = InProgressAttempt.tryFromMap(map)!;
      expect(back.startedAt, DateTime(2026, 5, 1, 12));
    });

    test('remaining never exceeds the duration', () {
      final a = attempt(DateTime.utc(2026, 5, 1, 12));
      expect(
        a.remaining(DateTime.utc(2026, 4, 30, 12)),
        const Duration(minutes: 30),
      );
    });
  });
}
