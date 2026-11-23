import 'package:pilotiq/src/domain/dates.dart';

/// Answers given in one local calendar day (box `daily`, key = [date]).
class DailyStat {
  const DailyStat({required this.date, this.answered = 0, this.correct = 0});

  /// `yyyy-MM-dd`, local date at the moment of the answer.
  final String date;
  final int answered;
  final int correct;

  static String keyFor(DateTime now) => dateKey(now);

  DailyStat recorded({required bool correct}) => DailyStat(
    date: date,
    answered: answered + 1,
    correct: this.correct + (correct ? 1 : 0),
  );

  Map<String, dynamic> toMap() => {
    'date': date,
    'answered': answered,
    'correct': correct,
  };

  factory DailyStat.fromMap(Map<dynamic, dynamic> m) => DailyStat(
    date: m['date'] as String,
    answered: (m['answered'] as num?)?.toInt() ?? 0,
    correct: (m['correct'] as num?)?.toInt() ?? 0,
  );

  @override
  bool operator ==(Object other) =>
      other is DailyStat &&
      other.date == date &&
      other.answered == answered &&
      other.correct == correct;

  @override
  int get hashCode => Object.hash(date, answered, correct);

  @override
  String toString() => 'DailyStat($date, $correct/$answered)';
}
