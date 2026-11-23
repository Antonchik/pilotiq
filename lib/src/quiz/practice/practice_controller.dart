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
    this.bookmarked = const {},
    this.limitReached = false,
    this.finished = false,
  });

  final List<Question> queue;

  /// Answer layout of every question of the queue, fixed for the session.
  final Map<String, ShuffledAnswers> shuffles;
  final QuestionLanguage language;
  final int index;

  /// Canonical index of the answer given to a question in this session.
  final Map<String, int> selected;
  final Set<String> bookmarked;
  final bool limitReached;
  final bool finished;

  Question? get current => index < queue.length ? queue[index] : null;
  bool get currentAnswered =>
      current != null && selected.containsKey(current!.id);
  bool get isLast => index >= queue.length - 1;
  int get answeredCount => selected.length;

  int get correctCount => [
    for (final q in queue)
      if (selected[q.id] == q.correctIndex) q,
  ].length;
  int get wrongCount => answeredCount - correctCount;

  /// Ids of the questions answered wrongly in this session.
  List<String> get wrongIds => [
    for (final q in queue)
      if (selected.containsKey(q.id) && selected[q.id] != q.correctIndex) q.id,
  ];

  PracticeState copyWith({
    int? index,
    Map<String, int>? selected,
    Set<String>? bookmarked,
    bool? limitReached,
    bool? finished,
  }) => PracticeState(
    queue: queue,
    shuffles: shuffles,
    language: language,
    index: index ?? this.index,
    selected: selected ?? this.selected,
    bookmarked: bookmarked ?? this.bookmarked,
    limitReached: limitReached ?? this.limitReached,
    finished: finished ?? this.finished,
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
    return PracticeState(
      queue: queue,
      shuffles: {for (final q in queue) q.id: shuffledAnswers(q, random)},
      language: ref.read(effectiveQuestionLanguageProvider(args.licence)),
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
          state = AsyncData((state.value ?? start).copyWith(limitReached: true));
          return;
        }
      }
      final shuffled = start.shuffles[question.id]!;
      final canonical = shuffled.canonicalIndexAt(position);
      final latest = state.value ?? start;
      state = AsyncData(
        latest.copyWith(selected: {...latest.selected, question.id: canonical}),
      );
      await repository.recordAnswer(
        args.licence,
        question.id,
        canonical == question.correctIndex,
        now,
      );
    } on Object catch (e) {
      debugPrint('Could not save the answer: $e');
    } finally {
      _answering = false;
    }
  }

  /// Moves to the next question (only after the current one was answered).
  void next() {
    final s = state.value;
    if (s == null || !s.currentAnswered) return;
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
