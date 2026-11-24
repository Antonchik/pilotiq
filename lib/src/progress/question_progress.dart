import 'package:pilotiq/src/progress/stored_time.dart';

/// Learning state of one question (box `progress_<licence>`, key = qid).
class QuestionProgress {
  const QuestionProgress({
    required this.qid,
    this.seen = 0,
    this.correct = 0,
    this.wrong = 0,
    this.consecutiveCorrect = 0,
    this.box = 1,
    this.lastAnsweredAt,
    this.dueAt,
    this.bookmarked = false,
    this.recent = const [],
  });

  /// How many latest answers are kept in [recent].
  static const int recentLimit = 3;

  final String qid;

  /// Number of answers given (correct + wrong).
  final int seen;
  final int correct;
  final int wrong;
  final int consecutiveCorrect;

  /// Leitner box, 1..5.
  final int box;
  final DateTime? lastAnsweredAt;
  final DateTime? dueAt;
  final bool bookmarked;

  /// Latest answers, oldest first (true = correct), at most [recentLimit].
  final List<bool> recent;

  QuestionProgress copyWith({
    int? seen,
    int? correct,
    int? wrong,
    int? consecutiveCorrect,
    int? box,
    DateTime? lastAnsweredAt,
    DateTime? dueAt,
    bool? bookmarked,
    List<bool>? recent,
  }) => QuestionProgress(
    qid: qid,
    seen: seen ?? this.seen,
    correct: correct ?? this.correct,
    wrong: wrong ?? this.wrong,
    consecutiveCorrect: consecutiveCorrect ?? this.consecutiveCorrect,
    box: box ?? this.box,
    lastAnsweredAt: lastAnsweredAt ?? this.lastAnsweredAt,
    dueAt: dueAt ?? this.dueAt,
    bookmarked: bookmarked ?? this.bookmarked,
    recent: recent ?? this.recent,
  );

  Map<String, dynamic> toMap() => {
    'qid': qid,
    'seen': seen,
    'correct': correct,
    'wrong': wrong,
    'consecutiveCorrect': consecutiveCorrect,
    'box': box,
    'lastAnsweredAt': lastAnsweredAt == null
        ? null
        : encodeMoment(lastAnsweredAt!),
    'dueAt': dueAt == null ? null : encodeMoment(dueAt!),
    'bookmarked': bookmarked,
    'recent': recent,
  };

  factory QuestionProgress.fromMap(Map<dynamic, dynamic> m) {
    int i(String k, int d) => (m[k] as num?)?.toInt() ?? d;
    DateTime? t(String k) => decodeMoment(m[k]);

    final recent = <bool>[
      if (m['recent'] is List)
        for (final v in m['recent'] as List)
          if (v is bool) v,
    ];
    return QuestionProgress(
      qid: m['qid'] as String,
      seen: i('seen', 0),
      correct: i('correct', 0),
      wrong: i('wrong', 0),
      consecutiveCorrect: i('consecutiveCorrect', 0),
      box: i('box', 1).clamp(1, 5),
      lastAnsweredAt: t('lastAnsweredAt'),
      dueAt: t('dueAt'),
      bookmarked: m['bookmarked'] == true,
      recent: recent.length > recentLimit
          ? recent.sublist(recent.length - recentLimit)
          : recent,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is QuestionProgress &&
      other.qid == qid &&
      other.seen == seen &&
      other.correct == correct &&
      other.wrong == wrong &&
      other.consecutiveCorrect == consecutiveCorrect &&
      other.box == box &&
      other.lastAnsweredAt == lastAnsweredAt &&
      other.dueAt == dueAt &&
      other.bookmarked == bookmarked &&
      _listEq(other.recent, recent);

  @override
  int get hashCode => Object.hash(
    qid,
    seen,
    correct,
    wrong,
    consecutiveCorrect,
    box,
    lastAnsweredAt,
    dueAt,
    bookmarked,
  );

  @override
  String toString() => 'QuestionProgress(${toMap()})';

  static bool _listEq(List<bool> a, List<bool> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
