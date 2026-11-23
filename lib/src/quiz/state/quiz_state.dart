import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:pilotiq/src/models.dart';

final quizStateProvider = ChangeNotifierProvider((ref) => QuizState());

class QuizState with ChangeNotifier {
  double _progress = 0;
  Answer? _selected;
  final List<Question> questions = [];
  final List<Answer> answers = [];
  String subject = '';
  bool isExam = false;

  final PageController controller = PageController();

  double get progress => _progress;

  Answer? get selected => _selected;

  bool get result {
    var right = 0;
    var wrong = 0;
    for (final answer in answers) {
      if (answer.isCorrect) {
        right += 1;
      } else {
        wrong += 1;
      }
    }
    return !(right / (right + wrong) < 0.75);
  }

  set progress(double newValue) {
    _progress = newValue;
    notifyListeners();
  }

  set selected(Answer? newValue) {
    _selected = newValue;
    notifyListeners();
  }

  set answer(Answer newValue) {
    answers.add(newValue);
  }

  void reset() {
    _progress = 0;
    _selected = null;
    answers.clear();
    questions.clear();
    isExam = false;
    // notifyListeners();
  }

  void nextPage() async {
    await controller.nextPage(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }

  void continueFromPage(int index, {isAnimated = false}) async {
    if (isAnimated) {
      await controller.animateToPage(
        index,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    } else {
      controller.jumpToPage(index);
    }
  }
}
