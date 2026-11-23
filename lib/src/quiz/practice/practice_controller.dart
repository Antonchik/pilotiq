import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/bank/licence_provider.dart';
import 'package:pilotiq/src/bank/models.dart';
import 'package:pilotiq/src/bank/question_bank_repository.dart';
import 'package:pilotiq/src/domain/access_policy.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/progress/providers.dart';
import 'package:pilotiq/src/progress/user_settings.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';
import 'package:pilotiq/src/quiz/practice/practice_session.dart';

/// What a practice session is asked to run.
class PracticeArgs {
  const PracticeArgs({
    required this.licence,
    required this.subject,
    required this.mode,
    required this.questions,
    this.retryIds = const [],
  });

  final Licence licence;
  final SubjectId subject;
  final PracticeMode mode;

  /// All questions of the subject, in the order of the bank.
  final List<Question> questions;

  /// Questions of a [PracticeMode.retry] session.
  final List<String> retryIds;

  PracticeArgs retry(List<String> ids) => PracticeArgs(
    licence: licence,
    subject: subject,
    mode: PracticeMode.retry,
    questions: questions,
    retryIds: ids,
  );
}

/// State of one practice session. Answers are kept in the canonical order of
/// the bank; [shuffles] tells how they are laid out on the screen.
class PracticeState {
  const PracticeState({
    required this.queue,
    required this.shuffles,
    required this.language,
    this.index = 0,
    this.selected = const {},
    this.saved = const {},
    this.bookmarked = const {},
    this.limitReached = false,
    this.finished = false,
    this.bookmarkErrors = 0,
  });

  final List<Question> queue;

  /// Answer layout of every question of the queue, fixed for the session.
  final Map<String, ShuffledAnswers> shuffles;
  final QuestionLanguage language;
  final int index;

  /// Canonical index of the answer given to a question in this session.
  final Map<String, int> selected;

  /// Questions whose answer is stored. An answer that could not be stored is
  /// in [selected] (it is shown) but not here, and does not count anywhere.
  final Set<String> saved;
  final Set<String> bookmarked;
  final bool limitReached;
  final bool finished;

  /// How many times saving a bookmark failed (the screen tells the user).
  final int bookmarkErrors;

  Question? get current => index < queue.length ? queue[index] : null;
  bool get currentAnswered =>
      current != null && selected.containsKey(current!.id);

  /// The current question was answered but the answer is not stored yet.
  bool get currentUnsaved => currentAnswered && !saved.contains(current!.id);
  bool get isLast => index >= queue.length - 1;

  /// Number of stored answers of this session.
  int get answeredCount => saved.length;

  int get correctCount => [
    for (final q in queue)
      if (saved.contains(q.id) && selected[q.id] == q.correctIndex) q,
  ].length;
  int get wrongCount => answeredCount - correctCount;

  /// Ids of the questions answered wrongly (and stored) in this session.
  List<String> get wrongIds => [
    for (final q in queue)
      if (saved.contains(q.id) && selected[q.id] != q.correctIndex) q.id,
  ];

  PracticeState copyWith({
    int? index,
    Map<String, int>? selected,
    Set<String>? saved,
    Set<String>? bookmarked,
    bool? limitReached,
    bool? finished,
    int? bookmarkErrors,
  }) => PracticeState(
    queue: queue,
    shuffles: shuffles,
    language: language,
    index: index ?? this.index,
    selected: selected ?? this.selected,
    saved: saved ?? this.saved,
    bookmarked: bookmarked ?? this.bookmarked,
    limitReached: limitReached ?? this.limitReached,
    finished: finished ?? this.finished,
    bookmarkErrors: bookmarkErrors ?? this.bookmarkErrors,
  );
}

/// Controller of one practice screen. All state lives here; the provider is
/// overridden by every screen, so sessions never share state.
class PracticeController extends AsyncNotifier<PracticeState> {
  PracticeController(this.args);

  final PracticeArgs args;

  bool _answering = false;
  bool _bookmarking = false;

  @override
  Future<PracticeState> build() async {
    // Premium bought from the paywall lifts the daily limit at once.
    ref.listen(isPremiumProvider, (previous, premium) {
      final s = state.value;
      if (premium && s != null && s.limitReached) {
        state = AsyncData(s.copyWith(limitReached: false));
      }
    });
    final repository = ref.read(progressRepositoryProvider);
    final progress = await repository.allProgress(args.licence);
    final queue = buildPracticeQueue(
      mode: args.mode,
      questions: args.questions,
      progress: progress,
      now: ref.read(clockProvider).now(),
      retryIds: args.retryIds,
    );
    final random = ref.read(randomProvider);
    final settings = await ref.read(userSettingsProvider.future);
    return PracticeState(
      queue: queue,
      shuffles: {for (final q in queue) q.id: shuffledAnswers(q, random)},
      language: effectiveQuestionLanguage(
        args.licence,
        settings.questionLanguage,
      ),
      bookmarked: {
        for (final q in queue)
          if (progress[q.id]?.bookmarked ?? false) q.id,
      },
    );
  }

  /// Answers the current question with the answer shown at [position]. The
  /// answer is stored exactly once per question: further taps, rebuilds and
  /// taps that arrive while the first one is being processed are ignored.
  Future<void> answer(int position) async {
    final start = state.value;
    if (_answering || start == null || start.limitReached) return;
    final question = start.current;
    if (question == null || start.selected.containsKey(question.id)) return;
    _answering = true;
    try {
      final repository = ref.read(progressRepositoryProvider);
      final now = ref.read(clockProvider).now();
      if (!ref.read(isPremiumProvider)) {
        final today = await repository.dailyStat(now);
        if (!ref.mounted) return;
        if (!AccessPolicy.canAnswer(false, today.answered)) {
          state = AsyncData(
            (state.value ?? start).copyWith(limitReached: true),
          );
          return;
        }
      }
      final shuffled = start.shuffles[question.id]!;
      final canonical = shuffled.canonicalIndexAt(position);
      final latest = state.value ?? start;
      state = AsyncData(
        latest.copyWith(selected: {...latest.selected, question.id: canonical}),
      );
      await _store(question.id, canonical == question.correctIndex, now);
    } finally {
      _answering = false;
    }
  }

  /// Stores the answer of [qid]; the question counts as saved only when the
  /// write succeeded.
  Future<void> _store(String qid, bool correct, DateTime now) async {
    try {
      await ref
          .read(progressRepositoryProvider)
          .recordAnswer(args.licence, qid, correct, now);
    } on Object catch (e) {
      debugPrint('Could not save the answer: $e');
      return;
    }
    if (!ref.mounted) return;
    ref.invalidate(
      subjectStatsProvider((licence: args.licence, subject: args.subject)),
    );
    final latest = state.value;
    if (latest == null) return;
    state = AsyncData(latest.copyWith(saved: {...latest.saved, qid}));
  }

  /// Stores again the answer that could not be stored. It writes the same
  /// choice as before; a question that is already stored is never written
  /// twice.
  Future<void> retrySave() async {
    final s = state.value;
    final question = s?.current;
    if (_answering || s == null || question == null) return;
    if (!s.selected.containsKey(question.id) || s.saved.contains(question.id)) {
      return;
    }
    _answering = true;
    try {
      await _store(
        question.id,
        s.selected[question.id] == question.correctIndex,
        ref.read(clockProvider).now(),
      );
    } finally {
      _answering = false;
    }
  }

  /// Checks the daily limit again (a new day may have started or Premium may
  /// have been bought) and lets the user continue when it allows.
  Future<void> recheckLimit() async {
    final s = state.value;
    if (_answering || s == null || !s.limitReached) return;
    _answering = true;
    try {
      var allowed = ref.read(isPremiumProvider);
      if (!allowed) {
        final today = await ref
            .read(progressRepositoryProvider)
            .dailyStat(ref.read(clockProvider).now());
        allowed = AccessPolicy.canAnswer(false, today.answered);
      }
      if (allowed && ref.mounted) {
        final latest = state.value ?? s;
        state = AsyncData(latest.copyWith(limitReached: false));
      }
    } finally {
      _answering = false;
    }
  }

  /// Moves to the next question (only after the current one was answered).
  void next() {
    final s = state.value;
    if (s == null || !s.currentAnswered || s.currentUnsaved) return;
    final index = s.index + 1;
    state = AsyncData(
      s.copyWith(index: index, finished: index >= s.queue.length),
    );
  }

  void finish() {
    final s = state.value;
    if (s == null || s.finished) return;
    state = AsyncData(s.copyWith(finished: true));
  }

  Future<void> toggleBookmark() async {
    final s = state.value;
    final question = s?.current;
    if (_bookmarking || s == null || question == null) return;
    _bookmarking = true;
    try {
      final value = await ref
          .read(progressRepositoryProvider)
          .toggleBookmark(args.licence, question.id);
      if (!ref.mounted) return;
      ref.invalidate(
        subjectStatsProvider((licence: args.licence, subject: args.subject)),
      );
      final latest = state.value ?? s;
      state = AsyncData(
        latest.copyWith(
          bookmarked: {
            for (final id in latest.bookmarked)
              if (id != question.id) id,
            if (value) question.id,
          },
        ),
      );
    } on Object catch (e) {
      debugPrint('Could not save the bookmark: $e');
      final latest = state.value;
      if (ref.mounted && latest != null) {
        state = AsyncData(
          latest.copyWith(bookmarkErrors: latest.bookmarkErrors + 1),
        );
      }
    } finally {
      _bookmarking = false;
    }
  }
}

/// Overridden by every practice screen with its own controller.
final practiceControllerProvider =
    AsyncNotifierProvider.autoDispose<PracticeController, PracticeState>(
      () => throw UnimplementedError('Provided by PracticeScreen'),
    );

/// Identifies a subject of a licence.
typedef SubjectKey = ({Licence licence, SubjectId subject});

/// Counters of a subject (coverage, due, mistakes, bookmarks). They are
/// derived from the stored progress; screens invalidate the provider when
/// they come back from a session.
final subjectStatsProvider = FutureProvider.autoDispose
    .family<SubjectStats, SubjectKey>((ref, key) async {
      final bank = await ref.watch(bankProvider(key.licence).future);
      final progress = await ref
          .watch(progressRepositoryProvider)
          .allProgress(key.licence);
      return computeSubjectStats(
        bank.questionsOf(key.subject),
        progress,
        ref.read(clockProvider).now(),
      );
    });
