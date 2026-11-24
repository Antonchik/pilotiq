import 'dart:math' as math;

import 'package:pilotiq/src/progress/user_settings.dart';
import 'package:timezone/timezone.dart' as tz;

/// Which kind of message a reminder carries.
enum ReminderKind {
  /// Ordinary study reminder (days to the exam, what is left of the goal).
  study,

  /// Seven days before the exam.
  examWeek,

  /// The day before the exam.
  examEve,

  /// The day after the exam: "How did it go?".
  afterExam,
}

class ReminderMessage {
  const ReminderMessage({required this.title, required this.body});

  final String title;
  final String body;

  @override
  bool operator ==(Object other) =>
      other is ReminderMessage && other.title == title && other.body == body;

  @override
  int get hashCode => Object.hash(title, body);
}

/// Texts of the reminders, already localised. The planner only chooses which
/// one to use and with which numbers.
abstract class ReminderTexts {
  /// [remaining]: answers left to the daily goal, [daysToExam]: null without
  /// an exam date, [dueQuestions]: questions due for review today (0 for
  /// days other than today).
  ReminderMessage study({
    required int remaining,
    int? daysToExam,
    int dueQuestions = 0,
  });

  ReminderMessage examWeek({required int remaining});

  ReminderMessage examEve();

  ReminderMessage afterExam();
}

/// One notification of the schedule.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.at,
    required this.kind,
    required this.title,
    required this.body,
  });

  /// Stable per calendar day (days since 1970-01-01), so planning the same
  /// day twice replaces the notification instead of duplicating it.
  final int id;
  final tz.TZDateTime at;
  final ReminderKind kind;
  final String title;
  final String body;

  @override
  bool operator ==(Object other) =>
      other is PlannedReminder &&
      other.id == id &&
      other.at.isAtSameMomentAs(at) &&
      other.kind == kind &&
      other.title == title &&
      other.body == body;

  @override
  int get hashCode => Object.hash(id, at.millisecondsSinceEpoch, kind, title);

  @override
  String toString() => 'PlannedReminder($id, $at, $kind)';
}

/// Length of the sliding window of planned days.
const int reminderWindowDays = 14;

/// Hard upper bound of the schedule. iOS keeps at most 64 pending
/// notifications; the window is far below that, the limit is a safety net.
const int maxScheduledReminders = 60;

int _dayNumber(int year, int month, int day) =>
    DateTime.utc(year, month, day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

/// Builds the schedule for the next [windowDays] days. Pure: everything it
/// needs comes in as arguments.
///
/// * At most one reminder per day, at [reminderTime] on the wall clock of
///   [location] (so it stays at that time across daylight saving changes).
/// * Today is left out when the time has passed or the daily goal is reached.
/// * With an exam date: the exam day itself has no reminder, the day before
///   and seven days before have their own texts, the day after gets "How did
///   the exam go?", and nothing is planned after that.
/// * Without [reminderTime] the schedule is empty.
List<PlannedReminder> planReminders({
  required ReminderTime? reminderTime,
  required DateTime? examDate,
  required int dailyGoal,
  required int answeredToday,
  required DateTime now,
  required tz.Location location,
  required ReminderTexts texts,
  int dueQuestions = 0,
  int windowDays = reminderWindowDays,
}) {
  if (reminderTime == null) return const [];
  final current = tz.TZDateTime.from(now, location);
  final examDay = examDate == null
      ? null
      : _dayNumber(examDate.year, examDate.month, examDate.day);
  final days = math.min(windowDays, maxScheduledReminders);
  final plan = <PlannedReminder>[];
  for (var i = 0; i < days; i++) {
    final at = tz.TZDateTime(
      location,
      current.year,
      current.month,
      current.day + i,
      reminderTime.hour,
      reminderTime.minute,
    );
    final day = _dayNumber(at.year, at.month, at.day);
    final untilExam = examDay == null ? null : examDay - day;
    // After the follow-up day nothing more is planned.
    if (untilExam != null && untilExam < -1) break;
    // The exam day itself is left in peace.
    if (untilExam == 0) continue;
    if (!at.isAfter(current)) continue;
    final today = i == 0;
    final afterExam = untilExam == -1;
    if (!afterExam && today && answeredToday >= dailyGoal) continue;

    final remaining = today
        ? math.max(0, dailyGoal - answeredToday)
        : dailyGoal;
    final ReminderKind kind;
    final ReminderMessage message;
    if (afterExam) {
      kind = ReminderKind.afterExam;
      message = texts.afterExam();
    } else if (untilExam == 1) {
      kind = ReminderKind.examEve;
      message = texts.examEve();
    } else if (untilExam == 7) {
      kind = ReminderKind.examWeek;
      message = texts.examWeek(remaining: remaining);
    } else {
      kind = ReminderKind.study;
      message = texts.study(
        remaining: remaining,
        daysToExam: untilExam,
        dueQuestions: today ? dueQuestions : 0,
      );
    }
    plan.add(
      PlannedReminder(
        id: day,
        at: at,
        kind: kind,
        title: message.title,
        body: message.body,
      ),
    );
  }
  return plan;
}
