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
    final already = stored.any((a) => a.id == attempt.id);
    if (!already) await _repository.saveAttempt(attempt);
    try {
      await _repository.clearInProgressAttempt(
        attempt.licence,
        attempt.subject,
      );
    } on Object catch (e) {
      debugPrint('Could not clear the unfinished exam: $e');
    }
    if (!already) {
      // Final answer of every answered question, once, for the Leitner state
      // and "my mistakes". Best effort: the attempt itself is already safe.
      for (final id in attempt.questionIds) {
        final a = attempt.answers[id];
        final q = bank[id];
        if (a == null || q == null) continue;
        try {
          await _repository.recordAnswer(
            attempt.licence,
            id,
            a == q.correctIndex,
            now,
          );
        } on Object catch (e) {
          debugPrint('Could not add an exam answer to the progress: $e');
        }
      }
    }
    return attempt;
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
  }) => ExamState(
    phase: phase ?? this.phase,
    language: language,
    attemptId: attemptId,
    questions: questions,
    shuffles: shuffles,
    answers: answers ?? this.answers,
    flagged: flagged ?? this.flagged,
    index: index ?? this.index,
    startedAt: startedAt,
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
  final ValueNotifier<Duration> remaining = ValueNotifier(Duration.zero);

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
    ref.onDispose(() => _timer?.cancel());
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
    var stored = await _repo.loadInProgressAttempt(args.licence, args.subject);
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
      if (stored.isExpired(now)) {
        return _closeRestored(restored, ExamNotice.expiredWhileClosed);
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
  Future<ExamState> _closeRestored(ExamState s, ExamNotice notice) async {
    final attempt = ExamFinalizer.buildAttempt(
      source: _snapshot(s),
      bank: _byId,
      now: _now,
      reason: AttemptReason.timeout,
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

  InProgressAttempt _snapshot(ExamState s) => InProgressAttempt(
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
      for (final e in s.shuffles.entries) e.key: List<int>.of(e.value.order),
    },
  );

  void _afterStored() {
    ref.invalidate(
      subjectStatsProvider((licence: args.licence, subject: args.subject)),
    );
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
    final s = state.value;
    if (s == null || s.phase != ExamPhase.running) return;
    final left = s.deadline!.difference(_now);
    if (left <= Duration.zero) {
      remaining.value = Duration.zero;
      unawaited(_finish(AttemptReason.timeout));
      return;
    }
    remaining.value = Duration(seconds: (left.inMilliseconds / 1000).ceil());
  }

  bool _expiredNow(ExamState s) {
    if (s.deadline != null && !_now.isBefore(s.deadline!)) {
      unawaited(_finish(AttemptReason.timeout));
      return true;
    }
    return false;
  }

  ExamState? get _running {
    final s = state.value;
    if (s == null || s.phase != ExamPhase.running) return null;
    return _expiredNow(s) ? null : s;
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

  // Finishing ------------------------------------------------------------------

  /// The single way to end an exam (button, timeout, resumed attempt). The
  /// first call wins; later or concurrent ones return the same run.
  Future<void> _finish(AttemptReason reason) {
    final running = _finishFuture;
    if (running != null) return running;
    final s = state.value;
    if (s == null ||
        (s.phase != ExamPhase.running && s.phase != ExamPhase.resume)) {
      return Future.value();
    }
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
    final attempt = state.value?.attempt;
    if (attempt == null) return;
    try {
      await _persistFuture;
    } on Object {
      // A failed progress save does not matter any more.
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

/// Status of the exam tile. Opening it also closes an unfinished attempt whose
/// time is over: it is stored with the reason `timeout`.
final examStatusProvider = FutureProvider.autoDispose
    .family<ExamStatus, SubjectKey>((ref, key) async {
      final bank = await ref.watch(bankProvider(key.licence).future);
      final byId = {for (final q in bank.questionsOf(key.subject)) q.id: q};
      final repo = ref.watch(progressRepositoryProvider);
      final now = ref.read(clockProvider).now();
      var unfinished = await repo.loadInProgressAttempt(
        key.licence,
        key.subject,
      );
      var attempts = await repo.attempts(key.licence, subject: key.subject);
      if (unfinished != null) {
        final u = unfinished;
        if (attempts.any((a) => a.id == u.id)) {
          try {
            await repo.clearInProgressAttempt(key.licence, key.subject);
          } on Object catch (e) {
            debugPrint('Could not clear the unfinished exam: $e');
          }
          unfinished = null;
        } else if (u.isExpired(now)) {
          try {
            await ref
                .read(examFinalizerProvider)
                .persist(
                  ExamFinalizer.buildAttempt(
                    source: u,
                    bank: byId,
                    now: now,
                    reason: AttemptReason.timeout,
                  ),
                  byId,
                  now,
                );
            unfinished = null;
            attempts = await repo.attempts(key.licence, subject: key.subject);
            ref.invalidate(subjectStatsProvider(key));
          } on Object catch (e) {
            debugPrint('Could not save the expired exam: $e');
          }
        }
      }
      final real = attempts.where((a) => !a.isLegacy);
      return ExamStatus(
        last: real.isEmpty ? null : real.first,
        unfinished: unfinished,
      );
    });
