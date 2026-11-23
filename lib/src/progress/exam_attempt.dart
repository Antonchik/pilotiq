import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/domain/exam_scoring.dart';

enum AttemptReason { finished, timeout, legacy }

/// A finished exam simulation (box `attempts`, key = [id]). Legacy attempts
/// come from the pre-2.0 counters and carry no questions, only the outcome;
/// their timestamps are the Unix epoch.
class ExamAttempt {
  const ExamAttempt({
    required this.id,
    required this.licence,
    required this.subject,
    required this.startedAt,
    required this.finishedAt,
    required this.durationSec,
    required this.total,
    required this.correct,
    required this.passed,
    required this.reason,
    this.questionIds = const [],
    this.answers = const {},
    this.flagged = const [],
    this.topicBreakdown = const {},
  });

  final String id;
  final Licence licence;
  final SubjectId subject;
  final DateTime startedAt;
  final DateTime finishedAt;
  final int durationSec;
  final int total;
  final int correct;
  final bool passed;
  final List<String> questionIds;

  /// qid to the chosen answer as an index in the **canonical** order of the
  /// bank (`Question.answers`; the correct one is `correctIndex`), never in the
  /// shuffled display order. null = unanswered.
  final Map<String, int?> answers;
  final List<String> flagged;
  final Map<String, TopicScore> topicBreakdown;
  final AttemptReason reason;

  bool get isLegacy => reason == AttemptReason.legacy;

  double get ratio => total == 0 ? 0 : correct / total;

  Map<String, dynamic> toMap() => {
    'id': id,
    'licence': licence.id,
    'subject': subject.id,
    'startedAt': startedAt.toIso8601String(),
    'finishedAt': finishedAt.toIso8601String(),
    'durationSec': durationSec,
    'total': total,
    'correct': correct,
    'passed': passed,
    'questionIds': questionIds,
    'answers': answers,
    'flagged': flagged,
    'topicBreakdown': {
      for (final e in topicBreakdown.entries) e.key: e.value.toMap(),
    },
    'reason': reason.name,
  };

  /// Returns null if the record is damaged (unknown licence or subject, wrong
  /// types of required fields).
  static ExamAttempt? tryFromMap(Map<dynamic, dynamic> m) {
    try {
      final licence = Licence.fromId(_str(m['licence']));
      final subject = SubjectId.fromId(_str(m['subject']));
      final started = _date(m['startedAt']);
      final finished = _date(m['finishedAt']);
      final id = _str(m['id']);
      if (licence == null ||
          subject == null ||
          started == null ||
          finished == null ||
          id == null) {
        return null;
      }
      final rawTopics = m['topicBreakdown'];
      return ExamAttempt(
        id: id,
        licence: licence,
        subject: subject,
        startedAt: started,
        finishedAt: finished,
        durationSec: _int(m['durationSec']) ?? 0,
        total: _int(m['total']) ?? 0,
        correct: _int(m['correct']) ?? 0,
        passed: m['passed'] == true,
        questionIds: _strings(m['questionIds']),
        answers: _answers(m['answers']),
        flagged: _strings(m['flagged']),
        topicBreakdown: rawTopics is Map
            ? {
                for (final e in rawTopics.entries)
                  if (e.value is Map)
                    '${e.key}': TopicScore.fromMap(e.value as Map),
              }
            : const {},
        reason: AttemptReason.values.firstWhere(
          (r) => r.name == m['reason'],
          orElse: () => AttemptReason.finished,
        ),
      );
    } on Object {
      return null;
    }
  }
}

/// An exam attempt that has not finished yet; restored after the app is
/// minimised or killed. The remaining time is derived from [startedAt].
class InProgressAttempt {
  const InProgressAttempt({
    required this.id,
    required this.licence,
    required this.subject,
    required this.startedAt,
    required this.durationSec,
    required this.questionIds,
    this.answers = const {},
    this.flagged = const [],
    this.answerOrders = const {},
  });

  final String id;
  final Licence licence;
  final SubjectId subject;
  final DateTime startedAt;
  final int durationSec;
  final List<String> questionIds;

  /// qid to the chosen answer in the canonical bank order (see
  /// [ExamAttempt.answers]); null = unanswered.
  final Map<String, int?> answers;
  final List<String> flagged;

  /// How the answers were laid out on screen: qid to a permutation where
  /// position `i` shows the canonical answer `answerOrders[qid][i]`. Saved so
  /// that a restored attempt looks exactly as before. Missing qid = canonical.
  final Map<String, List<int>> answerOrders;

  DateTime get deadline => startedAt.add(Duration(seconds: durationSec));

  Duration remaining(DateTime now) {
    final left = deadline.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  bool isExpired(DateTime now) => !now.isBefore(deadline);

  InProgressAttempt copyWith({
    Map<String, int?>? answers,
    List<String>? flagged,
    Map<String, List<int>>? answerOrders,
  }) => InProgressAttempt(
    id: id,
    licence: licence,
    subject: subject,
    startedAt: startedAt,
    durationSec: durationSec,
    questionIds: questionIds,
    answers: answers ?? this.answers,
    flagged: flagged ?? this.flagged,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'licence': licence.id,
    'subject': subject.id,
    'startedAt': startedAt.toIso8601String(),
    'durationSec': durationSec,
    'questionIds': questionIds,
    'answers': answers,
    'flagged': flagged,
  };

  static InProgressAttempt? tryFromMap(Map<dynamic, dynamic> m) {
    try {
      final licence = Licence.fromId(_str(m['licence']));
      final subject = SubjectId.fromId(_str(m['subject']));
      final started = _date(m['startedAt']);
      final id = _str(m['id']);
      if (licence == null || subject == null || started == null || id == null) {
        return null;
      }
      final rawOrders = m['answerOrders'];
      return InProgressAttempt(
        id: id,
        licence: licence,
        subject: subject,
        startedAt: started,
        durationSec: _int(m['durationSec']) ?? 0,
        questionIds: _strings(m['questionIds']),
        answers: _answers(m['answers']),
        flagged: _strings(m['flagged']),
        answerOrders: rawOrders is Map
            ? {
                for (final e in rawOrders.entries)
                  if (e.value is List)
                    '${e.key}': [
                      for (final v in e.value as List)
                        if (v is num) v.toInt(),
                    ],
              }
            : const {},
      );
    } on Object {
      return null;
    }
  }
}

List<String> _strings(Object? v) =>
    v is List ? [for (final e in v) '$e'] : const [];

String? _str(Object? v) => v is String ? v : null;

int? _int(Object? v) => v is num ? v.toInt() : null;

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

Map<String, int?> _answers(Object? v) => v is Map
    ? {
        for (final e in v.entries) '${e.key}': _int(e.value),
      }
    : const {};
