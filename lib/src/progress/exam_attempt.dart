import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/domain/exam_scoring.dart';
import 'package:pilotiq/src/progress/stored_time.dart';

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
    this.unrecorded = const [],
  });

  final String id;
  final Licence licence;
  final SubjectId subject;
  final DateTime startedAt;
  final DateTime finishedAt;

  /// Questions whose answer of this attempt is not yet added to the progress
  /// of the questions. Filled when the attempt is stored and emptied one
  /// question at a time together with the progress write, so every answer is
  /// counted exactly once even if the app dies in between.
  final List<String> unrecorded;
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

  ExamAttempt withoutUnrecorded(Iterable<String> done) {
    final skip = done.toSet();
    return ExamAttempt(
      id: id,
      licence: licence,
      subject: subject,
      startedAt: startedAt,
      finishedAt: finishedAt,
      durationSec: durationSec,
      total: total,
      correct: correct,
      passed: passed,
      reason: reason,
      questionIds: questionIds,
      answers: answers,
      flagged: flagged,
      topicBreakdown: topicBreakdown,
      unrecorded: [
        for (final q in unrecorded)
          if (!skip.contains(q)) q,
      ],
    );
  }

  double get ratio => total == 0 ? 0 : correct / total;

  Map<String, dynamic> toMap() => {
    'id': id,
    'licence': licence.id,
    'subject': subject.id,
    'startedAt': encodeMoment(startedAt),
    'finishedAt': encodeMoment(finishedAt),
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
    'unrecorded': unrecorded,
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
        unrecorded: _strings(m['unrecorded']),
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
    this.closing,
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

  /// Set once the exam is being ended (button or timeout): the attempt may
  /// then only be finished, never continued.
  final AttemptReason? closing;

  DateTime get deadline => startedAt.add(Duration(seconds: durationSec));

  /// Time left at [now], always between zero and the full duration (a clock
  /// that was set back never gives more time than the exam has).
  Duration remaining(DateTime now) {
    final left = deadline.difference(now);
    final full = Duration(seconds: durationSec);
    return left.isNegative ? Duration.zero : (left > full ? full : left);
  }

  bool isExpired(DateTime now) => !now.isBefore(deadline);

  InProgressAttempt copyWith({
    Map<String, int?>? answers,
    List<String>? flagged,
    Map<String, List<int>>? answerOrders,
    DateTime? startedAt,
    AttemptReason? closing,
  }) => InProgressAttempt(
    id: id,
    licence: licence,
    subject: subject,
    startedAt: startedAt ?? this.startedAt,
    durationSec: durationSec,
    questionIds: questionIds,
    answers: answers ?? this.answers,
    flagged: flagged ?? this.flagged,
    answerOrders: answerOrders ?? this.answerOrders,
    closing: closing ?? this.closing,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'licence': licence.id,
    'subject': subject.id,
    'startedAt': encodeMoment(startedAt),
    'durationSec': durationSec,
    'questionIds': questionIds,
    'answers': answers,
    'flagged': flagged,
    'answerOrders': answerOrders,
    'closing': closing?.name,
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
        closing: AttemptReason.values
            .where((r) => r.name == m['closing'] && r != AttemptReason.legacy)
            .firstOrNull,
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

DateTime? _date(Object? v) => decodeMoment(v);

Map<String, int?> _answers(Object? v) => v is Map
    ? {for (final e in v.entries) '${e.key}': _int(e.value)}
    : const {};
