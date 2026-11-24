import 'package:pilotiq/src/domain/dates.dart';

/// Answers given in one local calendar day (box `daily`, key = [date]).
///
/// [answered] / [correct] count learning answers only: the free daily limit is
/// based on them. Answers of finished exam simulations are counted separately
/// in [examAnswered] / [examCorrect]; [activity] is the sum and tells whether
/// the day was active (streak).
class DailyStat {
  const DailyStat({
    required this.date,
    this.answered = 0,
    this.correct = 0,
    this.examAnswered = 0,
    this.examCorrect = 0,
  });

  /// `yyyy-MM-dd`, local date at the moment of the answer.
  final String date;
  final int answered;
  final int correct;
  final int examAnswered;
  final int examCorrect;

  /// Learning plus exam answers of the day.
  int get activity => answered + examAnswered;

  static String keyFor(DateTime now) => dateKey(now);

  /// One more answer. [exam] puts it into the exam counters instead.
  DailyStat recorded({required bool correct, bool exam = false}) => DailyStat(
    date: date,
    answered: answered + (exam ? 0 : 1),
    correct: this.correct + (!exam && correct ? 1 : 0),
    examAnswered: examAnswered + (exam ? 1 : 0),
    examCorrect: examCorrect + (exam && correct ? 1 : 0),
  );

  Map<String, dynamic> toMap() => {
    'date': date,
    'answered': answered,
    'correct': correct,
    'examAnswered': examAnswered,
    'examCorrect': examCorrect,
  };

  /// Records written before the exam counters existed read them as 0.
  factory DailyStat.fromMap(Map<dynamic, dynamic> m) => DailyStat(
    date: m['date'] as String,
    answered: (m['answered'] as num?)?.toInt() ?? 0,
    correct: (m['correct'] as num?)?.toInt() ?? 0,
    examAnswered: (m['examAnswered'] as num?)?.toInt() ?? 0,
    examCorrect: (m['examCorrect'] as num?)?.toInt() ?? 0,
  );

  @override
  bool operator ==(Object other) =>
      other is DailyStat &&
      other.date == date &&
      other.answered == answered &&
      other.correct == correct &&
      other.examAnswered == examAnswered &&
      other.examCorrect == examCorrect;

  @override
  int get hashCode =>
      Object.hash(date, answered, correct, examAnswered, examCorrect);

  @override
  String toString() =>
      'DailyStat($date, $correct/$answered, exam $examCorrect/$examAnswered)';
}
