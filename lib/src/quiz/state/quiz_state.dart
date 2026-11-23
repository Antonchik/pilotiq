import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:pilotiq/src/bank/models.dart';
import 'package:pilotiq/src/domain/exam_scoring.dart';
import 'package:pilotiq/src/progress/user_settings.dart';
import 'package:pilotiq/src/quiz/quiz_config.dart';

/// The state of one quiz screen; created anew for every screen.
final quizStateProvider = ChangeNotifierProvider.autoDispose(
  (ref) => QuizState(),
);

/// An answer given in the quiz, in the canonical order of the question.
class QuizAnswer {
  const QuizAnswer({required this.question, required this.canonicalIndex});

  final Question question;
  final int canonicalIndex;

  bool get isCorrect => canonicalIndex == question.correctIndex;
}

class QuizState with ChangeNotifier {
  double _progress = 0;
  bool _disposed = false;
  Quiz? _quiz;
  QuestionLanguage _language = QuestionLanguage.pl;

  final List<QuizAnswer> answers = [];
  final PageController controller = PageController();

  /// When the user pressed "Start" (exam mode).
  DateTime? startedAt;

  /// Set once the results page was reached, so that the result is stored once.
  bool finished = false;

  Quiz get quiz => _quiz!;
  List<Question> get questions => _quiz?.questions ?? const [];
  bool get isExam => _quiz?.type == QuizType.exam;
  QuestionLanguage get language => _language;
  double get progress => _progress;

  void configure(Quiz quiz, QuestionLanguage language) {
    _quiz = quiz;
    _language = language;
  }

  set progress(double newValue) {
    _progress = newValue;
    if (!_disposed) notifyListeners();
  }

  /// Result of the exam: the share of correct answers among **all** questions
  /// (an unanswered question counts as wrong).
  ExamScore get score => ExamScoring.score(
    [
      for (final q in questions)
        ScoredQuestion(qid: q.id, topic: q.topic, correctIndex: q.correctIndex),
    ],
    {for (final a in answers) a.question.id: a.canonicalIndex},
    passRatio: quiz.spec.passRatio,
  );

  bool get result => score.passed;

  Future<void> nextPage() async {
    if (_disposed || !controller.hasClients) return;
    await controller.nextPage(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    controller.dispose();
    super.dispose();
  }
}
