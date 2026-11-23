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

  /// qid to chosen index in the order shown, null = unanswered.
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

  /// Returns null if the record is damaged (unknown licence or subject).
  static ExamAttempt? tryFromMap(Map<dynamic, dynamic> m) {
    final licence = Licence.fromId(m['licence'] as String?);
    final subject = SubjectId.fromId(m['subject'] as String?);
    final started = DateTime.tryParse('${m['startedAt']}');
    final finished = DateTime.tryParse('${m['finishedAt']}');
    final id = m['id'];
    if (licence == null ||
        subject == null ||
        started == null ||
        finished == null ||
        id is! String) {
      return null;
    }
    final rawAnswers = m['answers'];
    final rawTopics = m['topicBreakdown'];
    return ExamAttempt(
      id: id,
      licence: licence,
      subject: subject,
      startedAt: started,
      finishedAt: finished,
      durationSec: (m['durationSec'] as num?)?.toInt() ?? 0,
      total: (m['total'] as num?)?.toInt() ?? 0,
      correct: (m['correct'] as num?)?.toInt() ?? 0,
      passed: m['passed'] == true,
      questionIds: _strings(m['questionIds']),
      answers: rawAnswers is Map
          ? {
              for (final e in rawAnswers.entries)
                '${e.key}': (e.value as num?)?.toInt(),
            }
          : const {},
      flagged: _strings(m['flagged']),
      topicBreakdown: rawTopics is Map
          ? {
              for (final e in rawTopics.entries)
                '${e.key}': TopicScore.fromMap(e.value as Map),
            }
          : const {},
      reason: AttemptReason.values.firstWhere(
        (r) => r.name == m['reason'],
        orElse: () => AttemptReason.finished,
      ),
    );
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
  });

  final String id;
  final Licence licence;
  final SubjectId subject;
  final DateTime startedAt;
  final int durationSec;
  final List<String> questionIds;
  final Map<String, int?> answers;
  final List<String> flagged;

  DateTime get deadline => startedAt.add(Duration(seconds: durationSec));

  Duration remaining(DateTime now) {
    final left = deadline.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  bool isExpired(DateTime now) => !now.isBefore(deadline);

  InProgressAttempt copyWith({
    Map<String, int?>? answers,
    List<String>? flagged,
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
    final licence = Licence.fromId(m['licence'] as String?);
    final subject = SubjectId.fromId(m['subject'] as String?);
    final started = DateTime.tryParse('${m['startedAt']}');
    final id = m['id'];
    if (licence == null ||
        subject == null ||
        started == null ||
        id is! String) {
      return null;
    }
    final rawAnswers = m['answers'];
    return InProgressAttempt(
      id: id,
      licence: licence,
      subject: subject,
      startedAt: started,
      durationSec: (m['durationSec'] as num?)?.toInt() ?? 0,
      questionIds: _strings(m['questionIds']),
      answers: rawAnswers is Map
          ? {
              for (final e in rawAnswers.entries)
                '${e.key}': (e.value as num?)?.toInt(),
            }
          : const {},
      flagged: _strings(m['flagged']),
    );
  }
}

List<String> _strings(Object? v) =>
    v is List ? [for (final e in v) '$e'] : const [];
