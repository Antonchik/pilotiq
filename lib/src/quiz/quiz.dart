import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:pilotiq/src/contdown_timer/countdown_timer.dart';
import 'package:pilotiq/src/models.dart';
import 'package:pilotiq/src/quiz/state/quiz_state.dart';
import 'package:pilotiq/src/quiz/widgets/congrats_page.dart';
import 'package:pilotiq/src/quiz/widgets/fail_page.dart';
import 'package:pilotiq/src/quiz/widgets/question_page.dart';
import 'package:pilotiq/src/quiz/widgets/start_page.dart';

class QuizScreen extends ConsumerWidget {
  QuizScreen({
    super.key,
    required this.quizId,
    required this.quiz,
  });

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
    final local = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            // AnimatedProgressbar(value: quizState.progress),
            LinearPercentIndicator(
              lineHeight: 5,
              barRadius: const Radius.circular(10),
              percent: quizState.progress,
              animation: true,
              animationDuration: 750,
              animateFromLastPercent: true,
              backgroundColor: Theme.of(context).colorScheme.primary,
              progressColor: Theme.of(context).colorScheme.background,
              leading: SizedBox(
                width: 45,
                child: Text('$currentQuestion/$questionQty',
                    style: TextStyle(
                        fontSize: 16.0,
                        color: Theme.of(context).colorScheme.onPrimary)),
              ),
              trailing: SizedBox(
                width: 65,
                child: quizId == 'exam'
                    ? CountDownTimer(
                        controller: timerController,
                        durationInMinutes: quiz.time)
                    : null,
              ),
            ),
          ],
        ),
        leading: quizState.progress > 0
            ? quizState.progress < 1
                ? IconButton(
                    icon: const Icon(FontAwesomeIcons.xmark),
                    onPressed: () async {
                      final proceed = await showDialog<bool>(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: Text(local.exitQuizTitle),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: Text(local.no),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: Text(local.yes),
                                ),
                              ],
                            );
                          });
                      if (proceed!) {
                        quizState.reset();
                        if (timerController.reset != null) {
                          timerController.reset!();
                        }
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      }
                    },
                  )
                : const SizedBox.shrink()
            : null,
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
