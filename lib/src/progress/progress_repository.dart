import 'dart:async';
import 'dart:io';

import 'package:hive_ce/hive.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/domain/leitner.dart';
import 'package:pilotiq/src/domain/mistakes.dart';
import 'package:pilotiq/src/progress/daily_stat.dart';
import 'package:pilotiq/src/progress/exam_attempt.dart';
import 'package:pilotiq/src/progress/question_progress.dart';
import 'package:pilotiq/src/progress/user_settings.dart';

typedef BoxOpener = Future<Box<dynamic>> Function(String name);

/// Coverage and accuracy of a set of questions (usually one subject).
class ProgressAggregate {
  const ProgressAggregate({
    required this.total,
    required this.covered,
    required this.correct,
    required this.wrong,
  });

  /// Number of questions asked about.
  final int total;

  /// Questions answered at least once.
  final int covered;
  final int correct;
  final int wrong;

  double get coverage => total == 0 ? 0 : covered / total;
  double get accuracy =>
      (correct + wrong) == 0 ? 0 : correct / (correct + wrong);
}

/// Hive-backed storage of learning progress. Records are JSON-like maps, so no
/// adapters are needed. Boxes: `progress_<licence>`, `daily`, `attempts`,
/// `config`. Time is always passed in by the caller.
class ProgressRepository {
  ProgressRepository({BoxOpener? openBox})
    : _openBox = openBox ?? _openWithBackup;

  static const String configBox = 'config';
  static const String dailyBox = 'daily';
  static const String attemptsBox = 'attempts';
  static String progressBoxName(Licence l) => 'progress_${l.id}';

  final BoxOpener _openBox;
  final Map<String, Future<Box<dynamic>>> _boxes = {};

  /// One write queue per opened `config` box object: repositories sharing the
  /// same open boxes share the queue, while freshly opened boxes (a new test,
  /// a reopened Hive) get a new one. Nothing is tied to the process or zone.
  static final Expando<_WriteQueue> _queues = Expando<_WriteQueue>();
  final LeitnerScheduler _leitner = const LeitnerScheduler();

  /// Opens a box once; a failed open is not cached, so the next call retries.
  Future<Box<dynamic>> _box(String name) {
    final cached = _boxes[name];
    if (cached != null) return cached;
    final opening = _openBox(name);
    _boxes[name] = opening;
    opening.then<void>(
      (_) {},
      onError: (Object _) {
        if (identical(_boxes[name], opening)) _boxes.remove(name);
      },
    );
    return opening;
  }

  /// Default opener: first without crash recovery. If the file is damaged, a
  /// copy `<file>.bak-<schema>` is saved once before Hive is allowed to
  /// truncate it during recovery.
  static Future<Box<dynamic>> _openWithBackup(String name) async {
    try {
      return await Hive.openBox<dynamic>(name, crashRecovery: false);
    } on Object {
      await _backupDamagedFile(name);
      return Hive.openBox<dynamic>(name);
    }
  }

  static Future<void> _backupDamagedFile(String name) async {
    try {
      // `homePath` is not on the public interface; the implementation has it.
      final home = (Hive as dynamic).homePath as String?;
      if (home == null) return;
      final file = File('$home/${name.toLowerCase()}.hive');
      final backup = File(
        '${file.path}.bak-${UserSettings.currentSchemaVersion}',
      );
      if (file.existsSync() && !backup.existsSync()) {
        await file.copy(backup.path);
      }
    } on Object {
      // A failed backup must not prevent the app from starting.
    }
  }

  /// Runs [action] after all earlier locked actions on the same boxes, so
  /// that read-modify-write sequences never lose updates. A failing action
  /// does not block the following ones.
  Future<T> _locked<T>(Future<T> Function() action) async {
    final anchor = await _box(configBox);
    final queue = _queues[anchor] ??= _WriteQueue();
    final previous = queue.tail;
    final done = Completer<void>();
    queue.tail = done.future;
    try {
      await previous;
      await _recoverPending();
      return await action();
    } finally {
      done.complete();
    }
  }

  // Settings -----------------------------------------------------------------

  Future<UserSettings> loadSettings() async {
    final box = await _box(configBox);
    return UserSettings.fromMap(box.toMap());
  }

  /// Saves the settings. `schemaVersion` is never written here (only
  /// [completeMigration] does), so a stale object cannot roll it back.
  Future<void> saveSettings(UserSettings settings) => _locked(() async {
    final map = settings.toMap()..remove('schemaVersion');
    await (await _box(configBox)).putAll(map);
  });

  /// Called by the legacy migration at its end: stores the migrated theme and
  /// the new schema version in one write.
  Future<void> completeMigration({
    required AppThemeMode themeMode,
    required int schemaVersion,
  }) => _locked(
    () async => (await _box(configBox))
        .putAll({'themeMode': themeMode.name, 'schemaVersion': schemaVersion}),
  );

  // Answers ------------------------------------------------------------------

  /// Records one answer: updates the Leitner state of [qid] and today's
  /// [DailyStat] within a single serialised call. The exam date from the
  /// settings limits the review interval.
  Future<QuestionProgress> recordAnswer(
    Licence licence,
    String qid,
    bool correct,
    DateTime now,
  ) => _locked(() async {
    final progress = await _box(progressBoxName(licence));
    final daily = await _box(dailyBox);
    final config = await _box(configBox);
    final examDate = UserSettings.fromMap(config.toMap()).examDate;

    final before =
        _readProgress(progress.get(qid)) ?? QuestionProgress(qid: qid);
    final after = _leitner.answer(
      before,
      correct: correct,
      now: now,
      examDate: examDate,
    );
    final key = DailyStat.keyFor(now);
    final stat = _readDaily(daily.get(key)) ?? DailyStat(date: key);

    // Journal of the two writes: if anything fails, the previous values are
    // restored (right away, or by the next locked call if even that fails),
    // so a retry by the caller is never counted twice.
    await config.put(_pendingKey, {
      'licence': licence.id,
      'qid': qid,
      'dailyKey': key,
      'prevProgress': _copyMap(progress.get(qid)),
      'prevDaily': _copyMap(daily.get(key)),
    });
    try {
      await progress.put(qid, after.toMap());
      await daily.put(key, stat.recorded(correct: correct).toMap());
      await config.delete(_pendingKey);
    } on Object {
      try {
        await _recoverPending();
      } on Object {
        // The journal stays; the next locked call restores it first.
      }
      rethrow;
    }
    return after;
  });

  static const String _pendingKey = 'pending_answer';

  static Map<dynamic, dynamic>? _copyMap(Object? v) =>
      v is Map ? Map<dynamic, dynamic>.of(v) : null;

  /// Rolls back an unfinished [recordAnswer] left in the journal, if any.
  Future<void> _recoverPending() async {
    final config = await _box(configBox);
    final j = config.get(_pendingKey);
    if (j is! Map) return;
    final licence = Licence.fromId(j['licence'] as String?);
    final qid = j['qid'];
    final dailyKey = j['dailyKey'];
    if (licence != null && qid is String && dailyKey is String) {
      final progress = await _box(progressBoxName(licence));
      final daily = await _box(dailyBox);
      Future<void> restore(Box<dynamic> box, String key, Object? prev) =>
          prev is Map ? box.put(key, prev) : box.delete(key);
      await restore(progress, qid, j['prevProgress']);
      await restore(daily, dailyKey, j['prevDaily']);
    }
    await config.delete(_pendingKey);
  }

  /// Flips the bookmark of [qid]; returns the new value.
  Future<bool> toggleBookmark(Licence licence, String qid) => _locked(() async {
    final box = await _box(progressBoxName(licence));
    final p = _readProgress(box.get(qid)) ?? QuestionProgress(qid: qid);
    final next = p.copyWith(bookmarked: !p.bookmarked);
    await box.put(qid, next.toMap());
    return next.bookmarked;
  });

  Future<QuestionProgress?> progressOf(Licence licence, String qid) async =>
      _readProgress((await _box(progressBoxName(licence))).get(qid));

  Future<Map<String, QuestionProgress>> allProgress(Licence licence) async {
    final box = await _box(progressBoxName(licence));
    final result = <String, QuestionProgress>{};
    for (final v in box.values) {
      final p = _readProgress(v);
      if (p != null) result[p.qid] = p;
    }
    return result;
  }

  /// Questions whose review is due at [now], the oldest due first.
  Future<List<QuestionProgress>> dueQuestions(
    Licence licence,
    DateTime now,
  ) async {
    final due = [
      for (final p in (await allProgress(licence)).values)
        if (p.seen > 0 && p.dueAt != null && !p.dueAt!.isAfter(now)) p,
    ]..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
    return due;
  }

  Future<List<QuestionProgress>> mistakes(Licence licence) async => [
    for (final p in (await allProgress(licence)).values)
      if (isMistake(p)) p,
  ];

  Future<List<QuestionProgress>> bookmarks(Licence licence) async => [
    for (final p in (await allProgress(licence)).values)
      if (p.bookmarked) p,
  ];

  /// Coverage and accuracy over the questions [qids] (e.g. one subject).
  Future<ProgressAggregate> aggregate(
    Licence licence,
    Iterable<String> qids,
  ) async {
    final all = await allProgress(licence);
    var total = 0;
    var covered = 0;
    var correct = 0;
    var wrong = 0;
    for (final id in qids) {
      total++;
      final p = all[id];
      if (p == null || p.seen == 0) continue;
      covered++;
      correct += p.correct;
      wrong += p.wrong;
    }
    return ProgressAggregate(
      total: total,
      covered: covered,
      correct: correct,
      wrong: wrong,
    );
  }

  // Daily stats --------------------------------------------------------------

  Future<DailyStat> dailyStat(DateTime day) async {
    final key = DailyStat.keyFor(day);
    return _readDaily((await _box(dailyBox)).get(key)) ?? DailyStat(date: key);
  }

  Future<List<DailyStat>> dailyStats() async {
    final result = <DailyStat>[];
    for (final v in (await _box(dailyBox)).values) {
      final s = _readDaily(v);
      if (s != null) result.add(s);
    }
    return result;
  }

  // Attempts -----------------------------------------------------------------

  Future<void> saveAttempt(ExamAttempt attempt) => _locked(
    () async => (await _box(attemptsBox)).put(attempt.id, attempt.toMap()),
  );

  /// Finished attempts of a licence (optionally one subject), newest first.
  Future<List<ExamAttempt>> attempts(
    Licence licence, {
    SubjectId? subject,
  }) async {
    final box = await _box(attemptsBox);
    final list = <ExamAttempt>[];
    for (final v in box.values) {
      if (v is! Map) continue;
      ExamAttempt? a;
      try {
        a = ExamAttempt.tryFromMap(v);
      } on Object {
        a = null;
      }
      if (a == null || a.licence != licence) continue;
      if (subject != null && a.subject != subject) continue;
      list.add(a);
    }
    list.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return list;
  }

  static String _inProgressKey(Licence l, SubjectId s) =>
      'inprogress_${l.id}_${s.id}';

  /// Stores the running attempt in `config`; call after every user action.
  Future<void> saveInProgressAttempt(InProgressAttempt attempt) => _locked(
    () async => (await _box(configBox))
        .put(_inProgressKey(attempt.licence, attempt.subject), attempt.toMap()),
  );

  Future<InProgressAttempt?> loadInProgressAttempt(
    Licence licence,
    SubjectId subject,
  ) async {
    final v = (await _box(configBox)).get(_inProgressKey(licence, subject));
    if (v is! Map) return null;
    try {
      return InProgressAttempt.tryFromMap(v);
    } on Object {
      return null;
    }
  }

  Future<void> clearInProgressAttempt(Licence licence, SubjectId subject) =>
      _locked(
        () async =>
            (await _box(configBox)).delete(_inProgressKey(licence, subject)),
      );

  // Decoding -----------------------------------------------------------------

  static QuestionProgress? _readProgress(Object? v) {
    if (v is! Map) return null;
    try {
      return QuestionProgress.fromMap(v);
    } on Object {
      return null;
    }
  }

  static DailyStat? _readDaily(Object? v) {
    if (v is! Map) return null;
    try {
      return DailyStat.fromMap(v);
    } on Object {
      return null;
    }
  }
}

class _WriteQueue {
  Future<void> tail = Future<void>.value();
}
