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

  group('the clock is set back: time used is never given back', () {
    testWidgets('by a day during the exam', (tester) async {
      await h.pump(tester);
      await h.open(tester);
      await h.start(tester);
      await h.advance(tester, const Duration(minutes: 5));
      expect(find.text('25:00'), findsOneWidget);

      await h.advance(tester, const Duration(days: -1));

      expect(find.text('25:00'), findsOneWidget);
      // Counting goes on from the new clock value.
      await h.advance(tester, const Duration(minutes: 1));
      expect(find.text('24:00'), findsOneWidget);
      final saved = (await h.unfinished())!;
      expect(saved.remaining(h.now), const Duration(minutes: 24));
    });

    testWidgets('by an hour after 20 minutes, earlier than the start', (
      tester,
    ) async {
      await h.pump(tester);
      await h.open(tester);
      await h.start(tester);
      await h.advance(tester, const Duration(minutes: 20));
      await h.advance(tester, const Duration(hours: -1));

      expect(find.text('10:00'), findsOneWidget);
      await h.advance(tester, const Duration(minutes: 1));
      expect(find.text('9:00'), findsOneWidget);
    });

    testWidgets('again and again: five times "+5 minutes, -2 hours" use up '
        '25 minutes and the sixth ends the exam', (tester) async {
      await h.pump(tester);
      await h.open(tester);
      await h.start(tester);
      for (var i = 1; i <= 5; i++) {
        await h.advance(tester, const Duration(minutes: 5));
        expect(find.text('${30 - 5 * i}:00'), findsOneWidget);
        if (i < 5) await h.advance(tester, const Duration(hours: -2));
      }
      // 25 minutes used; five more are enough.
      await h.advance(tester, const Duration(hours: -2));
      expect(find.text('5:00'), findsOneWidget);
      await h.advance(tester, const Duration(minutes: 6));

      final a = (await h.attempts()).single;
      expect(a.reason, AttemptReason.timeout);
      expect(a.durationSec, 1800);
    });

    testWidgets('while the app is in the background', (tester) async {
      await h.pump(tester);
      await h.open(tester);
      await h.start(tester);
      await h.advance(tester, const Duration(minutes: 10));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await settle(tester);
      h.now = h.now.subtract(const Duration(days: 1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);

      expect(find.text('20:00'), findsOneWidget);
    });

    testWidgets('between killing and restoring the app', (tester) async {
      await h.pump(tester);
      await h.open(tester);
      await h.start(tester);
      await h.advance(tester, const Duration(minutes: 10));
      await leave(tester);

      h.now = h.now.subtract(const Duration(days: 1));
      await h.open(tester);
      expect(find.textContaining('20 minutes left'), findsOneWidget);
      await tester.tap(find.byKey(const Key('exam_resume')));
      await settle(tester);

      expect(find.text('20:00'), findsOneWidget);
    });

    testWidgets('killed in the background (no leave dialog), clock set '
        'back by an hour before the restart', (tester) async {
      await h.pump(tester);
      await h.open(tester);
      await h.start(tester);
      await h.advance(tester, const Duration(minutes: 5));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await settle(tester);

      // The process dies; a new container opens the same storage.
      h.now = h.now.subtract(const Duration(hours: 1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await h.pump(tester);
      await h.open(tester);
      await tester.tap(find.byKey(const Key('exam_resume')));
      await settle(tester);

      expect(find.text('25:00'), findsOneWidget);
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

    test('remaining never exceeds the duration and used time stays', () {
      final a = attempt(DateTime.utc(2026, 5, 1, 12));
      expect(
        a.remaining(DateTime.utc(2026, 4, 30, 12)),
        const Duration(minutes: 30),
      );
      final b = a.copyWith(
        clock: ExamClock(
          elapsedMs: 600000,
          seenAt: DateTime.utc(2026, 5, 1, 12, 10),
          durationSec: 1800,
        ),
      );
      expect(
        b.remaining(DateTime.utc(2026, 4, 30)),
        const Duration(minutes: 20),
      );
      expect(
        b.remaining(DateTime.utc(2026, 5, 1, 12, 15)),
        const Duration(minutes: 15),
      );
    });

    test('a record of the old format counts from its start', () {
      final map = attempt(DateTime.utc(2026, 5, 1, 12)).toMap()
        ..remove('elapsedMs')
        ..remove('lastSeenAt');
      final back = InProgressAttempt.tryFromMap(map)!;
      expect(
        back.remaining(DateTime.utc(2026, 5, 1, 12, 10)),
        const Duration(minutes: 20),
      );
    });
  });
}
