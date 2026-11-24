import 'package:flutter_test/flutter_test.dart';
import 'package:pilotiq/src/notifications/reminder_planner.dart';
import 'package:pilotiq/src/progress/user_settings.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class _Texts implements ReminderTexts {
  const _Texts();

  @override
  ReminderMessage study({
    required int remaining,
    int? daysToExam,
    int dueQuestions = 0,
  }) => ReminderMessage(
    title: 'study',
    body: 'left=$remaining exam=$daysToExam due=$dueQuestions',
  );

  @override
  ReminderMessage examWeek({required int remaining}) =>
      ReminderMessage(title: 'week', body: 'left=$remaining');

  @override
  ReminderMessage examEve() => const ReminderMessage(title: 'eve', body: '');

  @override
  ReminderMessage afterExam() =>
      const ReminderMessage(title: 'after', body: '');
}

void main() {
  late tz.Location warsaw;
  setUpAll(() {
    tzdata.initializeTimeZones();
    warsaw = tz.getLocation('Europe/Warsaw');
  });

  tz.TZDateTime at(int y, int m, int d, [int h = 0, int min = 0]) =>
      tz.TZDateTime(warsaw, y, m, d, h, min);

  List<PlannedReminder> plan({
    required tz.TZDateTime now,
    ReminderTime? time = const ReminderTime(19, 0),
    DateTime? exam,
    int goal = 20,
    int answered = 0,
    int due = 0,
    int days = reminderWindowDays,
    DateTime? rawNow,
  }) => planReminders(
    reminderTime: time,
    examDate: exam,
    dailyGoal: goal,
    answeredToday: answered,
    dueQuestions: due,
    now: rawNow ?? now,
    location: warsaw,
    texts: const _Texts(),
    windowDays: days,
  );

  group('time of the reminder', () {
    test('19:00 and now 20:00: the first one is tomorrow at 19:00', () {
      final p = plan(now: at(2026, 11, 23, 20));
      expect(p.first.at, at(2026, 11, 24, 19));
      expect(p, hasLength(13));
    });

    test('19:00 and now 10:00: the first one is today at 19:00', () {
      final p = plan(now: at(2026, 11, 23, 10));
      expect(p.first.at, at(2026, 11, 23, 19));
      expect(p, hasLength(14));
    });

    test('exactly at the reminder time is already too late for today', () {
      final p = plan(now: at(2026, 11, 23, 19));
      expect(p.first.at, at(2026, 11, 24, 19));
    });

    test('a day change: 23:59 plans from tomorrow, 00:00 from today', () {
      expect(
        plan(now: at(2026, 11, 23, 23, 59)).first.at,
        at(2026, 11, 24, 19),
      );
      expect(plan(now: at(2026, 11, 24)).first.at, at(2026, 11, 24, 19));
    });

    test('the instant is read in the zone of the user, not in UTC', () {
      // 17:30 UTC on 1 June is 19:30 in Warsaw (CEST): 19:00 has passed.
      final p = plan(
        now: at(2026, 6, 1, 19, 30),
        rawNow: DateTime.utc(2026, 6, 1, 17, 30),
      );
      expect(p.first.at, at(2026, 6, 2, 19));
      // 16:30 UTC is 18:30 in Warsaw: today's reminder is still ahead.
      final earlier = plan(
        now: at(2026, 6, 1, 18, 30),
        rawNow: DateTime.utc(2026, 6, 1, 16, 30),
      );
      expect(earlier.first.at, at(2026, 6, 1, 19));
    });

    test('without a reminder time the schedule is empty', () {
      expect(plan(now: at(2026, 11, 23, 10), time: null), isEmpty);
    });
  });

  group('daily goal', () {
    test('goal reached today: no reminder for today', () {
      final p = plan(now: at(2026, 11, 23, 10), answered: 20);
      expect(p.first.at, at(2026, 11, 24, 19));
      expect(p, hasLength(13));
    });

    test('goal exceeded counts as reached', () {
      final p = plan(now: at(2026, 11, 23, 10), answered: 35);
      expect(p.first.at, at(2026, 11, 24, 19));
    });

    test('goal not reached: the text carries what is left', () {
      final p = plan(now: at(2026, 11, 23, 10), answered: 8, due: 5);
      expect(p.first.body, 'left=12 exam=null due=5');
      // Other days: the whole goal, and no due count (it is unknown yet).
      expect(p[1].body, 'left=20 exam=null due=0');
    });
  });

  group('exam date', () {
    test('no exam date: every day is an ordinary reminder', () {
      final p = plan(now: at(2026, 11, 23, 10));
      expect(p.every((r) => r.kind == ReminderKind.study), isTrue);
      expect(p.every((r) => r.body.contains('exam=null')), isTrue);
    });

    test(
      'exam in 3 days: 3 study reminders, "how did it go", then nothing',
      () {
        final p = plan(now: at(2026, 11, 23, 10), exam: DateTime(2026, 11, 26));
        expect(p.map((r) => r.kind), [
          ReminderKind.study,
          ReminderKind.study,
          ReminderKind.examEve,
          ReminderKind.afterExam,
        ]);
        expect(p.map((r) => r.at), [
          at(2026, 11, 23, 19),
          at(2026, 11, 24, 19),
          at(2026, 11, 25, 19),
          at(2026, 11, 27, 19),
        ]);
        expect(p.first.body, contains('exam=3'));
        expect(p[1].body, contains('exam=2'));
      },
    );

    test('the day before the exam has its own text', () {
      final p = plan(now: at(2026, 11, 23, 10), exam: DateTime(2026, 11, 24));
      expect(p.first.kind, ReminderKind.examEve);
      expect(p.first.title, 'eve');
    });

    test('seven days before the exam has its own text', () {
      final p = plan(now: at(2026, 11, 23, 10), exam: DateTime(2026, 11, 30));
      expect(p.first.kind, ReminderKind.examWeek);
      expect(p.first.title, 'week');
      expect(p[1].kind, ReminderKind.study);
    });

    test(
      'exam today: nothing today, "how did it go" tomorrow, then nothing',
      () {
        final p = plan(now: at(2026, 11, 23, 10), exam: DateTime(2026, 11, 23));
        expect(p, hasLength(1));
        expect(p.single.kind, ReminderKind.afterExam);
        expect(p.single.at, at(2026, 11, 24, 19));
      },
    );

    test('exam tomorrow: the eve reminder today, then the follow-up', () {
      final p = plan(now: at(2026, 11, 23, 10), exam: DateTime(2026, 11, 24));
      expect(p.map((r) => r.kind), [
        ReminderKind.examEve,
        ReminderKind.afterExam,
      ]);
    });

    test('exam yesterday: the follow-up today if its time is ahead', () {
      final ahead = plan(
        now: at(2026, 11, 23, 10),
        exam: DateTime(2026, 11, 22),
      );
      expect(ahead.map((r) => r.kind), [ReminderKind.afterExam]);
      expect(ahead.single.at, at(2026, 11, 23, 19));
      final late = plan(
        now: at(2026, 11, 23, 20),
        exam: DateTime(2026, 11, 22),
      );
      expect(late, isEmpty);
    });

    test('the follow-up is sent even when the goal is reached', () {
      final p = plan(
        now: at(2026, 11, 23, 10),
        exam: DateTime(2026, 11, 22),
        answered: 50,
      );
      expect(p.map((r) => r.kind), [ReminderKind.afterExam]);
    });

    test('exam long ago: no reminders at all', () {
      final p = plan(now: at(2026, 11, 23, 10), exam: DateTime(2026, 11, 10));
      expect(p, isEmpty);
    });

    test('exam far away: the window still holds only the next days', () {
      final p = plan(now: at(2026, 11, 23, 10), exam: DateTime(2027, 6, 1));
      expect(p, hasLength(14));
      expect(p.first.body, contains('exam=190'));
    });
  });

  group('window', () {
    test(
      'at most 14 days, one per day, unique ids, far below the iOS limit',
      () {
        final p = plan(now: at(2026, 11, 23, 10), days: 100);
        expect(p.length, lessThanOrEqualTo(maxScheduledReminders));
        expect(maxScheduledReminders, lessThanOrEqualTo(64));
        final defaultWindow = plan(now: at(2026, 11, 23, 10));
        expect(defaultWindow, hasLength(14));
        expect(defaultWindow.map((r) => r.id).toSet(), hasLength(14));
        final days = defaultWindow.map(
          (r) => (r.at.year, r.at.month, r.at.day),
        );
        expect(days.toSet(), hasLength(14));
        expect(defaultWindow.last.at, at(2026, 12, 6, 19));
      },
    );

    test('planning twice gives the same list (nothing is duplicated)', () {
      final a = plan(now: at(2026, 11, 23, 10), exam: DateTime(2026, 12, 3));
      final b = plan(now: at(2026, 11, 23, 10), exam: DateTime(2026, 12, 3));
      expect(a, b);
      expect({
        ...a.map((r) => r.id),
        ...b.map((r) => r.id),
      }, hasLength(a.length));
    });
  });

  group('daylight saving time (Europe/Warsaw)', () {
    test('spring: the reminder stays at 19:00 on the wall clock', () {
      // Clocks go forward on Sunday 2027-03-28.
      final p = plan(now: at(2027, 3, 25, 10));
      expect(p, hasLength(14));
      for (final r in p) {
        expect((r.at.hour, r.at.minute), (19, 0), reason: '${r.at}');
      }
      final byDay = {for (final r in p) r.at.day: r.at};
      expect(byDay[27]!.timeZoneOffset, const Duration(hours: 1));
      expect(byDay[28]!.timeZoneOffset, const Duration(hours: 2));
      // The distance between 27 and 28 March is 23 hours, not 24.
      expect(byDay[28]!.difference(byDay[27]!), const Duration(hours: 23));
    });

    test('autumn: the reminder stays at 19:00 on the wall clock', () {
      // Clocks go back on Sunday 2026-10-25.
      final p = plan(now: at(2026, 10, 22, 10));
      for (final r in p) {
        expect((r.at.hour, r.at.minute), (19, 0), reason: '${r.at}');
      }
      final byDay = {for (final r in p) r.at.day: r.at};
      expect(byDay[24]!.timeZoneOffset, const Duration(hours: 2));
      expect(byDay[25]!.timeZoneOffset, const Duration(hours: 1));
      expect(byDay[25]!.difference(byDay[24]!), const Duration(hours: 25));
      expect(p.map((r) => r.id).toSet(), hasLength(14));
    });

    test('a time that does not exist on the day of the change still gives one '
        'reminder on that day', () {
      final p = plan(now: at(2027, 3, 27, 10), time: const ReminderTime(2, 30));
      final onTheDay = p.where((r) => r.at.day == 28).toList();
      expect(onTheDay, hasLength(1));
      expect(onTheDay.single.at.month, 3);
      // Neither lost nor doubled: 14 days, 14 reminders in order.
      expect(p, hasLength(13));
      for (var i = 1; i < p.length; i++) {
        expect(p[i].at.isAfter(p[i - 1].at), isTrue);
      }
    });

    test('the exam countdown counts calendar days across the change', () {
      final p = plan(now: at(2027, 3, 26, 10), exam: DateTime(2027, 3, 29));
      expect(p.map((r) => r.kind), [
        ReminderKind.study,
        ReminderKind.study,
        ReminderKind.examEve,
        ReminderKind.afterExam,
      ]);
      expect(p.first.body, contains('exam=3'));
    });
  });
}
