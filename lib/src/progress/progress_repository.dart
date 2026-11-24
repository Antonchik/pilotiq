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

  static final List<RecoveryEvent> _recoveryEvents = [];

  /// Boxes of this repository that had to be recovered in this process (since
  /// start or the last [clearRecoveryEvents]). Non-empty means data may have
  /// been lost; the UI decides how to tell the user.
  static List<RecoveryEvent> get recoveryEvents =>
      List.unmodifiable(_recoveryEvents);

  static void clearRecoveryEvents() => _recoveryEvents.clear();

  /// How many backup copies of a damaged box file are kept.
  static const int keptBackups = 3;

  /// Default opener: first without crash recovery. If the file is damaged, a
  /// numbered copy `<file>.bak-<n>` is saved (the last [keptBackups] are kept)
  /// before Hive may truncate the file during recovery. If the box cannot be
  /// opened even with recovery (first frame damaged) and a copy exists, the
  /// file is deleted and an empty box is opened so the app can start. Every
  /// such case is added to [recoveryEvents].
  static Future<Box<dynamic>> _openWithBackup(String name) async {
    try {
      return await Hive.openBox<dynamic>(name, crashRecovery: false);
    } on Object {
      final backup = await _backupDamagedFile(name);
      try {
        final box = await Hive.openBox<dynamic>(name);
        _recoveryEvents.add(RecoveryEvent(name, backup, reset: false));
        return box;
      } on Object {
        if (backup == null) rethrow;
        await Hive.deleteBoxFromDisk(name);
        final box = await Hive.openBox<dynamic>(name);
        _recoveryEvents.add(RecoveryEvent(name, backup, reset: true));
        return box;
      }
    }
  }

  /// Copies the damaged file to the next free `.bak-<n>`; returns its path, or
  /// null if no copy could be made.
  static Future<String?> _backupDamagedFile(String name) async {
    try {
      // `homePath` is not on the public interface; the implementation has it.
      final home = (Hive as dynamic).homePath as String?;
      if (home == null) return null;
      final file = File('$home/${name.toLowerCase()}.hive');
      if (!file.existsSync()) return null;
      final prefix = '${file.uri.pathSegments.last}.bak-';
      final numbers = <int, File>{};
      for (final f in Directory(home).listSync().whereType<File>()) {
        final base = f.uri.pathSegments.last;
        if (!base.startsWith(prefix)) continue;
        final n = int.tryParse(base.substring(prefix.length));
        if (n != null) numbers[n] = f;
      }
      final next = numbers.isEmpty
          ? 1
          : numbers.keys.reduce((a, b) => a > b ? a : b) + 1;
      final backup = File('${file.path}.bak-$next');
      await file.copy(backup.path);
      numbers[next] = backup;
      final old = numbers.keys.toList()..sort();
      final surplus = old.length - keptBackups;
      for (final n in surplus > 0 ? old.take(surplus) : const <int>[]) {
        try {
          await numbers[n]!.delete();
        } on Object {
          // best effort
        }
      }
      return backup.path;
    } on Object {
      // A failed backup must not prevent the app from starting.
      return null;
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
    final box = await _box(configBox);
    // The default theme is not stored until the user (or the migration) has
    // chosen one: otherwise it would hide the 1.2.0 `dark` flag from a
    // migration that runs later.
    if (settings.themeMode == AppThemeMode.system &&
        !box.containsKey('themeMode')) {
      map.remove('themeMode');
    }
    await box.putAll(map);
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
  /// settings limits the review interval. With
  /// `countsTowardDailyLimit: false` (answers of a finished exam simulation)
  /// the question progress is updated as usual, but the day's statistics get
  /// the answer in `examAnswered` / `examCorrect`, so the free daily learning
  /// limit (based on `answered`) is not used up. Rollback on failure works in
  /// both modes.
  Future<QuestionProgress> recordAnswer(
    Licence licence,
    String qid,
    bool correct,
    DateTime now, {
    bool countsTowardDailyLimit = true,
  }) => _locked(
    () => _record(
      licence,
      qid,
      correct,
      now,
      countsTowardDailyLimit: countsTowardDailyLimit,
    ),
  );

  /// Adds the answer of [qid] given in the stored exam attempt [attemptId] to
  /// the progress (like [recordAnswer] with `countsTowardDailyLimit: false`)
  /// and removes [qid] from the attempt's `unrecorded` list **in the same
  /// journaled step**: either both happen or none. Returns false (and writes
  /// nothing) if the attempt is gone or the answer was already counted, so a
  /// repeated or interrupted run never counts an answer twice.
  Future<bool> recordAttemptAnswer(
    String attemptId,
    String qid, {
    required bool correct,
    required DateTime now,
  }) => _locked(() async {
    final attempts = await _box(attemptsBox);
    final raw = attempts.get(attemptId);
    final attempt = raw is Map ? ExamAttempt.tryFromMap(raw) : null;
    if (attempt == null || !attempt.unrecorded.contains(qid)) return false;
    await _record(
      attempt.licence,
      qid,
      correct,
      now,
      countsTowardDailyLimit: false,
      attemptId: attemptId,
      attemptAfter: attempt.withoutUnrecorded([qid]).toMap(),
    );
    return true;
  });

  /// Removes [qids] from the attempt's `unrecorded` list without touching the
  /// progress (answers that cannot be counted, e.g. the question left the
  /// bank).
  Future<void> dropUnrecordedAnswers(String attemptId, Iterable<String> qids) =>
      _locked(() async {
        final attempts = await _box(attemptsBox);
        final raw = attempts.get(attemptId);
        final attempt = raw is Map ? ExamAttempt.tryFromMap(raw) : null;
        if (attempt == null) return;
        await attempts.put(attemptId, attempt.withoutUnrecorded(qids).toMap());
      });

  /// Stored attempts of [licence] that still have answers to count.
  Future<List<ExamAttempt>> attemptsWithUnrecordedAnswers(
    Licence licence,
  ) async => [
    for (final a in await attempts(licence))
      if (a.unrecorded.isNotEmpty) a,
  ];

  Future<QuestionProgress> _record(
    Licence licence,
    String qid,
    bool correct,
    DateTime now, {
    required bool countsTowardDailyLimit,
    String? attemptId,
    Map<String, dynamic>? attemptAfter,
  }) async {
    final progress = await _box(progressBoxName(licence));
    final daily = await _box(dailyBox);
    final config = await _box(configBox);
    final attempts = attemptId == null ? null : await _box(attemptsBox);
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

    // Journal of the writes: if anything fails, the previous values are
    // restored (right away, or by the next locked call if even that fails),
    // so a retry by the caller is never counted twice.
    await config.put(_pendingKey, {
      'licence': licence.id,
      'qid': qid,
      'dailyKey': key,
      'prevProgress': _copyMap(progress.get(qid)),
      'prevDaily': _copyMap(daily.get(key)),
      'attemptId': ?attemptId,
      if (attemptId != null) 'prevAttempt': _copyMap(attempts!.get(attemptId)),
    });
    try {
      await progress.put(qid, after.toMap());
      await daily.put(
        key,
        stat.recorded(correct: correct, exam: !countsTowardDailyLimit).toMap(),
      );
      if (attemptId != null) await attempts!.put(attemptId, attemptAfter);
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
  }

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
      final attemptId = j['attemptId'];
      if (attemptId is String) {
        await restore(await _box(attemptsBox), attemptId, j['prevAttempt']);
      }
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

/// A box that was opened by recovering a damaged file.
class RecoveryEvent {
  const RecoveryEvent(this.box, this.backupPath, {required this.reset});

  /// Box name, e.g. `config`, `progress_ppla`, `attempts`.
  final String box;

  /// Copy of the damaged file made before recovery; null if it failed.
  final String? backupPath;

  /// true: nothing could be read and the box was reset to empty; false: the
  /// file was truncated at the damaged place and the rest kept.
  final bool reset;

  @override
  String toString() => 'RecoveryEvent($box, reset: $reset, $backupPath)';
}

class _WriteQueue {
  Future<void> tail = Future<void>.value();
}
