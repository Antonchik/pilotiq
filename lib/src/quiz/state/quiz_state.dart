import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/models.dart';

final quizStateProvider = ChangeNotifierProvider((ref) => QuizState());

class QuizState with ChangeNotifier {
  double _progress = 0;
  Answer? _selected;
  final List<bool> answers = [];
  bool isExam = false;

  final PageController controller = PageController();

  double get progress => _progress;

  Answer? get selected => _selected;

  bool get result {
    var right = 0;
    var wrong = 0;
    for (final answer in answers) {
      if (answer) {
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

  set answer(bool newValue) {
    answers.add(newValue);
    notifyListeners();
  }

  void reset() {
    _progress = 0;
    _selected = null;
    answers.clear();
    isExam = false;
    notifyListeners();
  }

  void nextPage() async {
    await controller.nextPage(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }
}
