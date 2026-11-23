import 'package:flutter_test/flutter_test.dart';
import 'package:pilotiq/src/bank/models.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/progress/question_progress.dart';
import 'package:pilotiq/src/quiz/practice/practice_session.dart';

Question q(String id) => Question(
  id: id,
  number: id,
  topic: id.substring(0, 5),
  subject: SubjectId.airLaw,
  text: LocalizedText(pl: id),
  answers: [for (var i = 0; i < 4; i++) LocalizedText(pl: 'a$i')],
  correctIndex: 0,
);

void main() {
  final now = DateTime(2026, 5, 10, 12);
  final questions = [for (var i = 1; i <= 5; i++) q('PL010-000$i')];

  QuestionProgress p(
    String id, {
    int correct = 0,
    int wrong = 0,
    int consecutive = 0,
    DateTime? last,
    DateTime? due,
    bool bookmarked = false,
  }) => QuestionProgress(
    qid: id,
    seen: correct + wrong,
    correct: correct,
    wrong: wrong,
    consecutiveCorrect: consecutive,
    lastAnsweredAt: last,
    dueAt: due,
    bookmarked: bookmarked,
  );

  List<String> ids(List<Question> l) => [for (final x in l) x.id];

  test('learn: not seen first (bank order), then ascending accuracy', () {
    final progress = {
      'PL010-0001': p('PL010-0001', correct: 3, wrong: 1),
      'PL010-0003': p('PL010-0003', correct: 0, wrong: 2),
      'PL010-0004': p('PL010-0004', correct: 1, wrong: 1),
    };
    final queue = buildPracticeQueue(
      mode: PracticeMode.learn,
      questions: questions,
      progress: progress,
      now: now,
    );
    expect(ids(queue), [
      'PL010-0002',
      'PL010-0005',
      'PL010-0003',
      'PL010-0004',
      'PL010-0001',
    ]);
  });

  test('a bookmarked but never answered question counts as not seen', () {
    final queue = buildPracticeQueue(
      mode: PracticeMode.learn,
      questions: questions,
      progress: {'PL010-0001': p('PL010-0001', bookmarked: true)},
      now: now,
    );
    expect(queue.first.id, 'PL010-0001');
  });

  test('review: only due questions, the oldest due first', () {
    final progress = {
      'PL010-0001': p(
        'PL010-0001',
        correct: 1,
        due: now.add(const Duration(days: 1)),
      ),
      'PL010-0002': p(
        'PL010-0002',
        correct: 1,
        due: now.subtract(const Duration(days: 1)),
      ),
      'PL010-0003': p('PL010-0003', correct: 1, due: now),
      'PL010-0004': p(
        'PL010-0004',
        correct: 1,
        due: now.subtract(const Duration(days: 3)),
      ),
    };
    final queue = buildPracticeQueue(
      mode: PracticeMode.review,
      questions: questions,
      progress: progress,
      now: now,
    );
    expect(ids(queue), ['PL010-0004', 'PL010-0002', 'PL010-0003']);
  });

  test('mistakes: wrong and fewer than two correct in a row', () {
    final progress = {
      'PL010-0001': p('PL010-0001', wrong: 1),
      'PL010-0002': p('PL010-0002', wrong: 1, correct: 1, consecutive: 1),
      'PL010-0003': p('PL010-0003', wrong: 1, correct: 2, consecutive: 2),
      'PL010-0004': p('PL010-0004', correct: 3, consecutive: 3),
    };
    final queue = buildPracticeQueue(
      mode: PracticeMode.mistakes,
      questions: questions,
      progress: progress,
      now: now,
    );
    expect(ids(queue), ['PL010-0001', 'PL010-0002']);
  });

  test('bookmarks and retry', () {
    final progress = {
      'PL010-0002': p('PL010-0002', bookmarked: true),
      'PL010-0005': p('PL010-0005', bookmarked: true),
    };
    expect(
      ids(
        buildPracticeQueue(
          mode: PracticeMode.bookmarks,
          questions: questions,
          progress: progress,
          now: now,
        ),
      ),
      ['PL010-0002', 'PL010-0005'],
    );
    expect(
      ids(
        buildPracticeQueue(
          mode: PracticeMode.retry,
          questions: questions,
          progress: progress,
          now: now,
          retryIds: ['PL010-0004', 'PL010-9999', 'PL010-0001'],
        ),
      ),
      ['PL010-0004', 'PL010-0001'],
    );
  });

  test('stats count coverage, accuracy, due, mistakes and bookmarks', () {
    final progress = {
      'PL010-0001': p(
        'PL010-0001',
        correct: 2,
        wrong: 1,
        consecutive: 0,
        due: now.subtract(const Duration(hours: 1)),
        bookmarked: true,
      ),
      'PL010-0002': p('PL010-0002', correct: 1, consecutive: 1, due: now),
      'PL010-0003': p('PL010-0003', bookmarked: true),
      'OTHER-0001': p('OTHER-0001', wrong: 5),
    };
    final stats = computeSubjectStats(questions, progress, now);
    expect(stats.total, 5);
    expect(stats.covered, 2);
    expect(stats.unseen, 3);
    expect(stats.correct, 3);
    expect(stats.wrong, 1);
    expect(stats.due, 2);
    expect(stats.mistakes, 1);
    expect(stats.bookmarks, 2);
    expect(stats.accuracy, closeTo(0.75, 1e-9));
  });

  test('empty progress gives zero stats without NaN', () {
    final stats = computeSubjectStats(const [], const {}, now);
    expect(stats.coverage, 0);
    expect(stats.accuracy, 0);
    expect(stats.hasAnswers, isFalse);
  });
}
