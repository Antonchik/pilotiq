import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pilotiq/src/contdown_timer/countdown_timer.dart';
import 'package:pilotiq/src/models.dart';
import 'package:pilotiq/src/quiz/state/quiz_state.dart';
import 'package:pilotiq/src/quiz/widgets/animated_progress_bar.dart';
import 'package:pilotiq/src/quiz/widgets/congrats_page.dart';
import 'package:pilotiq/src/quiz/widgets/fail_page.dart';
import 'package:pilotiq/src/quiz/widgets/question_page.dart';
import 'package:pilotiq/src/quiz/widgets/start_page.dart';

class QuizScreen extends ConsumerWidget {
  QuizScreen({super.key, required this.quizId, required this.quiz});

  final String quizId;
  final Quiz quiz;

  final timerController = CountDownTimerController();

  void _stopTimer() {
    if (timerController.pause != null) {
      timerController.pause!();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizState = ref.watch(quizStateProvider);
    quizState.isExam = quizId == 'exam';
    final questionQty = quiz.questions.length;
    final currentQuestion =
        (quizState.progress * questionQty).toStringAsFixed(0);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            AnimatedProgressbar(value: quizState.progress),
          ],
        ),
        flexibleSpace: quiz.id == 'exam'
            ? CountDownTimer(controller: timerController, durationInMinutes: 20)
            : null,
        leading: IconButton(
          icon: const Icon(FontAwesomeIcons.xmark),
          onPressed: () {
            quizState.reset();
            if (timerController.reset != null) {
              timerController.reset!();
            }
            Navigator.pop(context);
          },
        ),
        actions: [
          Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.only(right: 10),
            child: Text('$currentQuestion/$questionQty'),
          )
        ],
      ),
      body: PageView.builder(
        physics: const NeverScrollableScrollPhysics(),
        scrollDirection: Axis.vertical,
        controller: quizState.controller,
        onPageChanged: (int idx) =>
            quizState.progress = (idx / (quiz.questions.length + 1)),
        itemBuilder: (BuildContext context, int idx) {
          if (idx == 0) {
            return StartPage(quiz: quiz, timerController: timerController);
          } else if (idx == quiz.questions.length + 1) {
            if (quizId != 'exam') {
              return CongratsPage(quiz: quiz, quizState: quizState);
            } else {
              _stopTimer();
              if (quizState.result) {
                return CongratsPage(quiz: quiz, quizState: quizState);
              } else {
                return FailPage(quiz: quiz, quizState: quizState);
              }
            }
          } else {
            return QuestionPage(question: quiz.questions[idx - 1]);
          }
        },
      ),
    );
  }
}
