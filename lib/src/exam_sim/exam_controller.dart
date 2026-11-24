import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/bank/licence_provider.dart';
import 'package:pilotiq/src/bank/models.dart';
import 'package:pilotiq/src/bank/question_bank_repository.dart';
import 'package:pilotiq/src/domain/access_policy.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/domain/exam_builder.dart';
import 'package:pilotiq/src/domain/exam_scoring.dart';
import 'package:pilotiq/src/progress/exam_attempt.dart';
import 'package:pilotiq/src/progress/providers.dart';
import 'package:pilotiq/src/progress/progress_repository.dart';
import 'package:pilotiq/src/progress/user_settings.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';
import 'package:pilotiq/src/quiz/practice/practice_controller.dart';
import 'package:pilotiq/src/subjects/subject_info.dart';

/// What an exam screen is asked to run.
class ExamArgs {
  const ExamArgs({
    required this.licence,
    required this.subject,
    required this.spec,
    required this.questions,
  });

  factory ExamArgs.fromSubject(SubjectInfo s) => ExamArgs(
    licence: s.licence,
    subject: s.id,
    spec: s.spec,
    questions: s.questions,
  );

  final Licence licence;
  final SubjectId subject;
  final ExamSpec spec;

  /// All questions of the subject in the order of the bank.
  final List<Question> questions;

  Map<String, Question> get byId => {for (final q in questions) q.id: q};

  int get passPercent => (spec.passRatio * 100).round();
}

/// Builds, stores and closes attempts. One instance per app: concurrent calls
/// for the same attempt share one run, so an attempt is stored and its
/// answers are added to the progress exactly once.
class ExamFinalizer {
  ExamFinalizer(this._repository);

  final ProgressRepository _repository;
  final Map<String, Future<ExamAttempt>> _inFlight = {};

  /// The result of [source] at [now]. A question that is no longer in [bank]
  /// is left out of the score. The id of the attempt is the id of [source], so
  /// storing it twice replaces the record instead of adding a second one.
  static ExamAttempt buildAttempt({
    required InProgressAttempt source,
    required Map<String, Question> bank,
    required DateTime now,
    required AttemptReason reason,
  }) {
    final present = [
      for (final id in source.questionIds)
        if (bank.containsKey(id)) bank[id]!,
    ];
    final answers = <String, int?>{};
    for (final id in source.questionIds) {
      final a = source.answers[id];
      final q = bank[id];
      answers[id] = a != null && q != null && a >= 0 && a < q.answers.length
          ? a
          : null;
    }
    final score = ExamScoring.score(
      [
        for (final q in present)
          ScoredQuestion(
            qid: q.id,
            topic: q.topic,
            correctIndex: q.correctIndex,
          ),
      ],
      answers,
      passRatio: ExamSpec.forSubject(
        source.subject,
        licence: source.licence,
      ).passRatio,
    );
    final deadline = source.deadline;
    final finishedAt =
        reason == AttemptReason.timeout || !now.isBefore(deadline)
        ? deadline
        : now;
    final used = finishedAt.difference(source.startedAt).inSeconds;
    return ExamAttempt(
      id: source.id,
      licence: source.licence,
      subject: source.subject,
      startedAt: source.startedAt,
      finishedAt: finishedAt,
      durationSec: used < 0
          ? 0
          : (used > source.durationSec ? source.durationSec : used),
      total: score.total,
      correct: score.correct,
      passed: score.passed,
      reason: reason,
      questionIds: source.questionIds,
      answers: answers,
      flagged: source.flagged,
      topicBreakdown: score.topicBreakdown,
      unrecorded: [
        for (final id in source.questionIds)
          if (answers[id] != null && bank.containsKey(id)) id,
      ],
    );
  }

  /// Stores [attempt], removes the unfinished record and adds the answers to
  /// the progress. Throws when the attempt could not be stored; then nothing
  /// else was done and the call can be repeated.
  Future<ExamAttempt> persist(
    ExamAttempt attempt,
    Map<String, Question> bank,
    DateTime now,
  ) {
    final running = _inFlight[attempt.id];
    if (running != null) return running;
    final future = _persist(attempt, bank, now);
    _inFlight[attempt.id] = future;
    unawaited(
      future.then<void>(
        (_) {
          _inFlight.remove(attempt.id);
        },
        onError: (Object _) {
          _inFlight.remove(attempt.id);
        },
      ),
    );
    return future;
  }

  Future<ExamAttempt> _persist(
    ExamAttempt attempt,
    Map<String, Question> bank,
    DateTime now,
  ) async {
    final stored = await _repository.attempts(
      attempt.licence,
      subject: attempt.subject,
    );
    var current = stored.where((a) => a.id == attempt.id).firstOrNull;
    if (current == null) {
      await _repository.saveAttempt(attempt);
      current = attempt;
    }
    try {
      await _repository.clearInProgressAttempt(
        attempt.licence,
        attempt.subject,
      );
    } on Object catch (e) {
      debugPrint('Could not clear the unfinished exam: $e');
    }
    // Throws when an answer could not be counted; the attempt is stored by
    // then and a repeated call counts only what is still missing.
    await _recordPending(current, bank, now);
    return attempt;
  }

  /// Counts the answers of stored attempts of [licence] that are not counted
  /// yet (the app was closed or storage failed while the attempt was ended).
  /// Every answer is counted exactly once; returns the number of attempts
  /// that were completed. [bank] holds the questions of the licence by id.
  Future<int> completePending(
    Licence licence,
    Map<String, Question> bank,
    DateTime now, {
    SubjectId? subject,
  }) async {
    var done = 0;
    final pending = [
      for (final a in await _repository.attempts(licence, subject: subject))
        if (a.unrecorded.isNotEmpty) a,
    ];
    for (final a in pending) {
      await _recordPending(a, bank, now);
      done++;
    }
    return done;
  }

  Future<void> _recordPending(
    ExamAttempt stored,
    Map<String, Question> bank,
    DateTime now,
  ) {
    final key = 'rec:${stored.id}';
    final running = _recording[key];
    if (running != null) return running;
    final future = _doRecordPending(stored, bank, now);
    _recording[key] = future;
    unawaited(
      future.then<void>(
        (_) {
          _recording.remove(key);
        },
        onError: (Object _) {
          _recording.remove(key);
        },
      ),
    );
    return future;
  }

  final Map<String, Future<void>> _recording = {};

  Future<void> _doRecordPending(
    ExamAttempt stored,
    Map<String, Question> bank,
    DateTime now,
  ) async {
    // A fresh read: another run may have counted some answers meanwhile.
    final latest = (await _repository.attempts(
      stored.licence,
      subject: stored.subject,
    )).where((a) => a.id == stored.id).firstOrNull;
    if (latest == null) return;
    final gone = [
      for (final id in latest.unrecorded)
        if (bank[id] == null || latest.answers[id] == null) id,
    ];
    if (gone.isNotEmpty) {
      await _repository.dropUnrecordedAnswers(latest.id, gone);
    }
    for (final id in latest.unrecorded) {
      if (gone.contains(id)) continue;
      await _repository.recordAttemptAnswer(
        latest.id,
        id,
        correct: latest.answers[id] == bank[id]!.correctIndex,
        now: now,
      );
    }
  }
}

final examFinalizerProvider = Provider<ExamFinalizer>(
  (ref) => ExamFinalizer(ref.watch(progressRepositoryProvider)),
);

enum ExamPhase { rules, limit, resume, running, finishing, done }

class ExamState {
  const ExamState({
    required this.phase,
    required this.language,
    this.attemptId = '',
    this.questions = const [],
    this.shuffles = const {},
    this.answers = const {},
    this.flagged = const {},
    this.index = 0,
    this.startedAt,
    this.durationSec = 0,
    this.persistFailed = false,
    this.startFailed = false,
    this.finishFailed = false,
    this.attempt,
    this.notice = ExamNotice.none,
  });

  final ExamPhase phase;
  final QuestionLanguage language;
  final String attemptId;
  final List<Question> questions;

  /// Layout of the answers on the screen (saved with the attempt).
  final Map<String, ShuffledAnswers> shuffles;

  /// Chosen answers in the canonical order of the bank.
  final Map<String, int> answers;
  final Set<String> flagged;
  final int index;
  final DateTime? startedAt;
  final int durationSec;
  final bool persistFailed;
  final bool startFailed;
  final bool finishFailed;

  /// The result, built when the exam ends; shown once it is stored.
  final ExamAttempt? attempt;
  final ExamNotice notice;

  Question? get current => index < questions.length ? questions[index] : null;
  int get answeredCount => [
    for (final q in questions)
      if (answers.containsKey(q.id)) q,
  ].length;
  int get unansweredCount => questions.length - answeredCount;
  int get flaggedCount => [
    for (final q in questions)
      if (flagged.contains(q.id)) q,
  ].length;
  DateTime? get deadline => startedAt?.add(Duration(seconds: durationSec));

  ExamState copyWith({
    ExamPhase? phase,
    Map<String, int>? answers,
    Set<String>? flagged,
    int? index,
    bool? persistFailed,
    bool? startFailed,
    bool? finishFailed,
    ExamAttempt? attempt,
    ExamNotice? notice,
    DateTime? startedAt,
  }) => ExamState(
    phase: phase ?? this.phase,
    language: language,
    attemptId: attemptId,
    questions: questions,
    shuffles: shuffles,
    answers: answers ?? this.answers,
    flagged: flagged ?? this.flagged,
    index: index ?? this.index,
    startedAt: startedAt ?? this.startedAt,
    durationSec: durationSec,
    persistFailed: persistFailed ?? this.persistFailed,
    startFailed: startFailed ?? this.startFailed,
    finishFailed: finishFailed ?? this.finishFailed,
    attempt: attempt ?? this.attempt,
    notice: notice ?? this.notice,
  );
}

/// Why the result screen carries a note.
enum ExamNotice { none, timeUp, expiredWhileClosed }

int _idCounter = 0;

/// Controller of one exam screen. All state lives here; the provider is
/// overridden by every screen, so two exams never share state. The clock and
/// the randomness come from the providers. The remaining time is always
/// derived from the start time, so it does not depend on frame rate, pauses
/// of the app or the lifetime of a timer.
class ExamController extends AsyncNotifier<ExamState> {
  ExamController(this.args);

  final ExamArgs args;

  /// Remaining time for the clock widget (updates once per second).
  late ValueNotifier<Duration> remaining;

  Timer? _timer;
  Future<void>? _finishFuture;
  Future<void>? _persistFuture;
  bool _persisting = false;
  bool _persistAgain = false;
  bool _starting = false;
  late Map<String, Question> _byId;

  ProgressRepository get _repo => ref.read(progressRepositoryProvider);
  DateTime get _now => ref.read(clockProvider).now();

  @override
  Future<ExamState> build() async {
    _timer?.cancel();
    _finishFuture = null;
    _starting = false;
    _byId = args.byId;
    remaining = ValueNotifier(Duration.zero);
    final clock = remaining;
    ref.onDispose(() {
      _timer?.cancel();
      clock.dispose();
    });
    ref.listen(isPremiumProvider, (previous, premium) {
      final s = state.value;
      if (premium && s != null && s.phase == ExamPhase.limit) {
        state = AsyncData(s.copyWith(phase: ExamPhase.rules));
      }
    });
    final settings = await ref.read(userSettingsProvider.future);
    final language = effectiveQuestionLanguage(
      args.licence,
      settings.questionLanguage,
    );
    final now = _now;
    try {
      // Answers of an attempt that was stored but not (fully) counted.
      await ref
          .read(examFinalizerProvider)
          .completePending(args.licence, _byId, now, subject: args.subject);
    } on Object catch (e) {
      debugPrint('Could not count the answers of a stored exam: $e');
    }
    var stored = await _repo.loadInProgressAttempt(args.licence, args.subject);
    if (stored != null && stored.startedAt.isAfter(now)) {
      // The clock was set back since the exam was started: the start moves
      // back with it, so the exam never has more time than its duration.
      stored = stored.copyWith(startedAt: now);
      try {
        await _repo.saveInProgressAttempt(stored);
      } on Object catch (e) {
        debugPrint('Could not store the new start of the exam: $e');
      }
    }
    if (stored != null) {
      final done = await _repo.attempts(args.licence, subject: args.subject);
      if (done.any((a) => a.id == stored!.id)) {
        // Already stored; only the unfinished record was left behind.
        try {
          await _repo.clearInProgressAttempt(args.licence, args.subject);
        } on Object catch (e) {
          debugPrint('Could not clear the unfinished exam: $e');
        }
        stored = null;
      }
    }
    if (stored != null) {
      final restored = _restore(stored, language, ExamPhase.resume);
      if (stored.closing != null) {
        // Ending had begun but the result was not stored: finish it, the exam
        // cannot be continued any more.
        return _closeRestored(restored, ExamNotice.none, stored.closing!);
      }
      if (stored.isExpired(now)) {
        return _closeRestored(
          restored,
          ExamNotice.expiredWhileClosed,
          AttemptReason.timeout,
        );
      }
      return restored;
    }
    final canStart = await _canStart();
    return ExamState(
      phase: canStart ? ExamPhase.rules : ExamPhase.limit,
      language: language,
    );
  }

  Future<bool> _canStart() async {
    final used = (await _repo.attempts(
      args.licence,
      subject: args.subject,
    )).where((a) => !a.isLegacy).length;
    return AccessPolicy.canStartExam(ref.read(isPremiumProvider), used);
  }

  ExamState _restore(
    InProgressAttempt stored,
    QuestionLanguage language,
    ExamPhase phase,
  ) {
    final questions = [
      for (final id in stored.questionIds)
        if (_byId.containsKey(id)) _byId[id]!,
    ];
    final shuffles = <String, ShuffledAnswers>{};
    for (final q in questions) {
      final saved = stored.answerOrders[q.id];
      final valid =
          saved != null &&
          saved.length == q.answers.length &&
          {...saved}.length == saved.length &&
          saved.every((i) => i >= 0 && i < q.answers.length);
      final order = valid
          ? saved
          : List<int>.generate(q.answers.length, (i) => i);
      shuffles[q.id] = ShuffledAnswers(
        order: List.unmodifiable(order),
        correctPosition: order.indexOf(q.correctIndex),
      );
    }
    final answers = {
      for (final q in questions)
        if (stored.answers[q.id] != null &&
            stored.answers[q.id]! >= 0 &&
            stored.answers[q.id]! < q.answers.length)
          q.id: stored.answers[q.id]!,
    };
    final firstOpen = questions.indexWhere((q) => !answers.containsKey(q.id));
    return ExamState(
      phase: phase,
      language: language,
      attemptId: stored.id,
      questions: questions,
      shuffles: shuffles,
      answers: answers,
      flagged: {...stored.flagged},
      index: firstOpen < 0 ? 0 : firstOpen,
      startedAt: stored.startedAt,
      durationSec: stored.durationSec,
    );
  }

  /// Ends a restored attempt whose time is over, storing it.
  Future<ExamState> _closeRestored(
    ExamState s,
    ExamNotice notice,
    AttemptReason reason,
  ) async {
    final attempt = ExamFinalizer.buildAttempt(
      source: _snapshot(s),
      bank: _byId,
      now: _now,
      reason: reason,
    );
    final base = s.copyWith(
      phase: ExamPhase.finishing,
      attempt: attempt,
      notice: notice,
    );
    try {
      await ref.read(examFinalizerProvider).persist(attempt, _byId, _now);
    } on Object catch (e) {
      debugPrint('Could not save the expired exam: $e');
      _finishFuture = null;
      return base.copyWith(finishFailed: true);
    }
    _afterStored();
    _finishFuture = Future<void>.value();
    return base.copyWith(phase: ExamPhase.done);
  }

  InProgressAttempt _snapshot(ExamState s, {AttemptReason? closing}) =>
      InProgressAttempt(
        closing: closing,
        id: s.attemptId,
        licence: args.licence,
        subject: args.subject,
        startedAt: s.startedAt!,
        durationSec: s.durationSec,
        questionIds: [for (final q in s.questions) q.id],
        answers: {for (final q in s.questions) q.id: s.answers[q.id]},
        flagged: [
          for (final q in s.questions)
            if (s.flagged.contains(q.id)) q.id,
        ],
        answerOrders: {
          for (final e in s.shuffles.entries)
            e.key: List<int>.of(e.value.order),
        },
      );

  void _afterStored() {
    final key = (licence: args.licence, subject: args.subject);
    ref.invalidate(subjectStatsProvider(key));
    ref.invalidate(examStatusProvider(key));
  }

  // Start / resume -------------------------------------------------------------

  /// Draws a fresh stratified sample and starts the clock. The attempt is
  /// stored first; if that fails the exam does not start.
  Future<void> start() async {
    final s = state.value;
    if (_starting || s == null || s.phase != ExamPhase.rules) return;
    if (args.questions.isEmpty) return;
    _starting = true;
    try {
      if (!await _canStart()) {
        _setIfMounted(s.copyWith(phase: ExamPhase.limit));
        return;
      }
      final random = ref.read(randomProvider);
      final picked = ExamBuilder.build(
        [
          for (final q in args.questions)
            ExamCandidate(id: q.id, number: q.number, topic: q.topic),
        ],
        args.spec,
        random,
      );
      final questions = [for (final c in picked) _byId[c.id]!];
      final shuffles = {
        for (final q in questions) q.id: shuffledAnswers(q, random),
      };
      final now = _now;
      final fresh = ExamState(
        phase: ExamPhase.running,
        language: s.language,
        attemptId:
            '${now.microsecondsSinceEpoch}-${_idCounter++}-'
            '${random.nextInt(1 << 30).toRadixString(36)}',
        questions: questions,
        shuffles: shuffles,
        startedAt: now,
        durationSec: args.spec.minutes * 60,
      );
      try {
        await _repo.saveInProgressAttempt(_snapshot(fresh));
      } on Object catch (e) {
        debugPrint('Could not store the new exam: $e');
        _setIfMounted(s.copyWith(startFailed: true));
        return;
      }
      if (!ref.mounted) return;
      state = AsyncData(fresh);
      ref.invalidate(
        examStatusProvider((licence: args.licence, subject: args.subject)),
      );
      _startTicker();
    } finally {
      _starting = false;
    }
  }

  /// Continues the unfinished exam found at the start.
  void resume() {
    final s = state.value;
    if (s == null || s.phase != ExamPhase.resume) return;
    if (_expiredNow(s)) return;
    state = AsyncData(s.copyWith(phase: ExamPhase.running));
    _startTicker();
  }

  /// Finishes the unfinished exam found at the start.
  Future<void> finishFromResume() {
    final s = state.value;
    if (s == null || s.phase != ExamPhase.resume) return Future.value();
    return _finish(AttemptReason.finished);
  }

  // Clock ------------------------------------------------------------------------

  void _startTicker() {
    _timer?.cancel();
    syncTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => syncTime());
  }

  /// Recomputes the remaining time from the start time; ends the exam when it
  /// is over. Called every second and when the app comes back to the front.
  void syncTime() {
    final current = state.value;
    if (current == null || current.phase != ExamPhase.running) return;
    final s = _anchor(current);
    final left = s.deadline!.difference(_now);
    if (left <= Duration.zero) {
      remaining.value = Duration.zero;
      unawaited(_finish(AttemptReason.timeout));
      return;
    }
    final full = Duration(seconds: s.durationSec);
    final shown = left > full ? full : left;
    remaining.value = Duration(seconds: (shown.inMilliseconds / 1000).ceil());
  }

  /// If the clock was set back to before the start, the start moves back too:
  /// the time left is never more than the duration of the exam.
  ExamState _anchor(ExamState s) {
    final now = _now;
    final start = s.startedAt;
    if (start == null || !now.isBefore(start)) return s;
    final next = s.copyWith(startedAt: now);
    state = AsyncData(next);
    if (s.phase == ExamPhase.running) _persist();
    return next;
  }

  bool _expiredNow(ExamState s) {
    final a = _anchor(s);
    if (a.deadline != null && !_now.isBefore(a.deadline!)) {
      unawaited(_finish(AttemptReason.timeout));
      return true;
    }
    return false;
  }

  ExamState? get _running {
    final s = state.value;
    if (s == null || s.phase != ExamPhase.running) return null;
    return _expiredNow(s) ? null : state.value;
  }

  // Actions ----------------------------------------------------------------------

  /// Chooses the answer shown at [position]; a later choice replaces it.
  void answer(int position) {
    final s = _running;
    final q = s?.current;
    if (s == null || q == null) return;
    final shuffled = s.shuffles[q.id]!;
    if (position < 0 || position >= shuffled.length) return;
    state = AsyncData(
      s.copyWith(
        answers: {...s.answers, q.id: shuffled.canonicalIndexAt(position)},
      ),
    );
    _persist();
  }

  void toggleFlag() {
    final s = _running;
    final q = s?.current;
    if (s == null || q == null) return;
    final flagged = {...s.flagged};
    if (!flagged.remove(q.id)) flagged.add(q.id);
    state = AsyncData(s.copyWith(flagged: flagged));
    _persist();
  }

  void goTo(int index) {
    final s = _running;
    if (s == null || index < 0 || index >= s.questions.length) return;
    state = AsyncData(s.copyWith(index: index));
  }

  void next() {
    final s = state.value;
    if (s != null) goTo(s.index + 1);
  }

  void previous() {
    final s = state.value;
    if (s != null) goTo(s.index - 1);
  }

  /// The user confirmed "Finish exam". Safe to call twice.
  Future<void> finish() {
    final s = state.value;
    if (s != null && s.phase == ExamPhase.running && _expiredNow(s)) {
      return _finishFuture ?? Future.value();
    }
    return _finish(AttemptReason.finished);
  }

  // Storing the running attempt ------------------------------------------------

  /// Stores the running attempt after an action. Saves never overlap and the
  /// latest state always wins; a failure is shown and retried by the user.
  void _persist() {
    if (_persisting) {
      _persistAgain = true;
      return;
    }
    _persisting = true;
    _persistFuture = _persistLoop();
  }

  Future<void> _persistLoop() async {
    try {
      do {
        _persistAgain = false;
        final s = state.value;
        if (s == null || s.phase != ExamPhase.running || !ref.mounted) break;
        try {
          await _repo.saveInProgressAttempt(_snapshot(s));
          _mark(persistFailed: false);
        } on Object catch (e) {
          debugPrint('Could not store the exam progress: $e');
          _mark(persistFailed: true);
        }
      } while (_persistAgain);
    } finally {
      _persisting = false;
    }
  }

  void _mark({required bool persistFailed}) {
    final s = state.value;
    if (!ref.mounted || s == null || s.persistFailed == persistFailed) return;
    state = AsyncData(s.copyWith(persistFailed: persistFailed));
  }

  void retryPersist() => _persist();

  /// Tries once more to store the running attempt, e.g. before the screen is
  /// left. Returns false if the latest answers are still not stored.
  Future<bool> flushProgress() async {
    final s = state.value;
    if (s == null || s.phase != ExamPhase.running) return true;
    _persist();
    try {
      await _persistFuture;
    } on Object {
      return false;
    }
    return !(state.value?.persistFailed ?? false);
  }

  // Finishing ------------------------------------------------------------------

  /// The single way to end an exam (button, timeout, resumed attempt). The
  /// first call wins; later or concurrent ones return the same run.
  Future<void> _finish(AttemptReason reason) {
    final running = _finishFuture;
    if (running != null) return running;
    final first = state.value;
    if (first == null ||
        (first.phase != ExamPhase.running && first.phase != ExamPhase.resume)) {
      return Future.value();
    }
    final s = _anchor(first);
    _timer?.cancel();
    final attempt = ExamFinalizer.buildAttempt(
      source: _snapshot(s),
      bank: _byId,
      now: _now,
      reason: reason,
    );
    state = AsyncData(
      s.copyWith(
        phase: ExamPhase.finishing,
        attempt: attempt,
        finishFailed: false,
        notice: reason == AttemptReason.timeout
            ? ExamNotice.timeUp
            : ExamNotice.none,
      ),
    );
    return _finishFuture = _store();
  }

  /// Stores the built result; shown as done only after it is stored.
  Future<void> _store() async {
    final current = state.value;
    final attempt = current?.attempt;
    if (current == null || attempt == null) return;
    try {
      await _persistFuture;
    } on Object {
      // A failed progress save does not matter any more.
    }
    try {
      // Ending has begun: should the app die now, the exam is only finished
      // when it is opened again, never continued.
      await _repo.saveInProgressAttempt(
        _snapshot(current, closing: attempt.reason),
      );
    } on Object catch (e) {
      debugPrint('Could not mark the exam as ending: $e');
    }
    try {
      await ref.read(examFinalizerProvider).persist(attempt, _byId, _now);
    } on Object catch (e) {
      debugPrint('Could not save the exam result: $e');
      _finishFuture = null;
      final s = state.value;
      if (ref.mounted && s != null) {
        state = AsyncData(s.copyWith(finishFailed: true));
      }
      return;
    }
    if (!ref.mounted) return;
    _afterStored();
    final s = state.value;
    if (s != null) state = AsyncData(s.copyWith(phase: ExamPhase.done));
  }

  /// Tries again to store a result that could not be stored.
  Future<void> retryFinish() {
    final s = state.value;
    if (s == null ||
        s.phase != ExamPhase.finishing ||
        !s.finishFailed ||
        _finishFuture != null) {
      return _finishFuture ?? Future.value();
    }
    state = AsyncData(s.copyWith(finishFailed: false));
    return _finishFuture = _store();
  }

  void _setIfMounted(ExamState s) {
    if (ref.mounted) state = AsyncData(s);
  }
}

/// Overridden by every exam screen with its own controller.
final examControllerProvider =
    AsyncNotifierProvider.autoDispose<ExamController, ExamState>(
      () => throw UnimplementedError('Provided by ExamScreen'),
    );

/// What the subject screen shows about the exam of a subject.
class ExamStatus {
  const ExamStatus({this.last, this.unfinished});

  /// Newest attempt of this version of the app.
  final ExamAttempt? last;
  final InProgressAttempt? unfinished;
}

/// Ends the unfinished attempt [u] if it has to be ended without the user: its
/// time is over, ending had begun, or its result is stored already. Returns
/// the attempt when it is still running (or could not be ended), else null.
Future<InProgressAttempt?> settleUnfinished({
  required ProgressRepository repo,
  required ExamFinalizer finalizer,
  required InProgressAttempt u,
  required Map<String, Question> byId,
  required DateTime now,
}) async {
  final stored = await repo.attempts(u.licence, subject: u.subject);
  if (stored.any((a) => a.id == u.id)) {
    try {
      await repo.clearInProgressAttempt(u.licence, u.subject);
    } on Object catch (e) {
      debugPrint('Could not clear the unfinished exam: $e');
    }
    return null;
  }
  if (!u.isExpired(now) && u.closing == null) return u;
  try {
    await finalizer.persist(
      ExamFinalizer.buildAttempt(
        source: u,
        bank: byId,
        now: now,
        reason: u.closing ?? AttemptReason.timeout,
      ),
      byId,
      now,
    );
    return null;
  } on Object catch (e) {
    debugPrint('Could not save the expired exam: $e');
    return u;
  }
}

/// Status of the exam tile. Opening it also closes an unfinished attempt whose
/// time is over: it is stored with the reason `timeout`.
final examStatusProvider = FutureProvider.autoDispose
    .family<ExamStatus, SubjectKey>((ref, key) async {
      final bank = await ref.watch(bankProvider(key.licence).future);
      final byId = {for (final q in bank.questionsOf(key.subject)) q.id: q};
      final repo = ref.watch(progressRepositoryProvider);
      final finalizer = ref.read(examFinalizerProvider);
      final now = ref.read(clockProvider).now();
      try {
        await finalizer.completePending(
          key.licence,
          byId,
          now,
          subject: key.subject,
        );
      } on Object catch (e) {
        debugPrint('Could not count the answers of a stored exam: $e');
      }
      var unfinished = await repo.loadInProgressAttempt(
        key.licence,
        key.subject,
      );
      if (unfinished != null) {
        unfinished = await settleUnfinished(
          repo: repo,
          finalizer: finalizer,
          u: unfinished,
          byId: byId,
          now: now,
        );
        if (unfinished == null) ref.invalidate(subjectStatsProvider(key));
      }
      final attempts = await repo.attempts(key.licence, subject: key.subject);
      final real = attempts.where((a) => !a.isLegacy);
      return ExamStatus(
        last: real.isEmpty ? null : real.first,
        unfinished: unfinished,
      );
    });
