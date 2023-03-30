import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:pilotiq/src/contdown_timer/countdown_timer.dart';
import 'package:pilotiq/src/hive_box_provider.dart';
import 'package:pilotiq/src/models.dart';
import 'package:pilotiq/src/quiz/state/quiz_state.dart';
import 'package:pilotiq/src/quiz/widgets/question_page.dart';
import 'package:pilotiq/src/quiz/widgets/results_page.dart';
import 'package:pilotiq/src/quiz/widgets/start_page.dart';

class QuizScreen extends ConsumerWidget {
  QuizScreen({
    super.key,
    required this.quizType,
    required this.quiz,
  });

  final QuizType quizType;
  final Quiz quiz;

  final timerController = CountDownTimerController();

  void _stopTimer() {
    if (timerController.pause != null) {
      timerController.pause!();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    final quizState = ref.read(quizStateProvider);
    quizState.subject = quiz.subject;
    quizState.isExam = quizType == QuizType.exam;
    if (quizState.isExam) {
      quizState.questions.addAll(quiz.questions.sublist(0, quiz.length));
    } else {
      quizState.questions.addAll(quiz.questions);
    }
    final questionQty = quizState.questions.length;
    final box = ref.read(examBoxProvider);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            // AnimatedProgressbar(value: quizState.progress),
            Consumer(
                builder: (BuildContext context, WidgetRef ref, Widget? child) {
              final quizState = ref.watch(quizStateProvider);
              final currentQuestion =
                  !quizState.isExam && quizState.progress == 0
                      ? ref.read(examBoxProvider).get(
                            quizState.subject,
                            defaultValue: 0,
                          )
                      : (quizState.progress * questionQty).ceil();
              return LinearPercentIndicator(
                lineHeight: 5,
                barRadius: const Radius.circular(10),
                percent: currentQuestion / questionQty,
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
                  child: quizType == QuizType.exam
                      ? CountDownTimer(
                          controller: timerController,
                          durationInMinutes: quiz.time)
                      : null,
                ),
              );
            }),
          ],
        ),
        leading: Consumer(
          builder: (BuildContext context, WidgetRef ref, Widget? child) {
            final quizState = ref.watch(quizStateProvider);
            if (quizState.progress == 1) return const SizedBox.shrink();
            return quizState.progress > 0
                ? CloseTestButton(
                    quizState: quizState, timerController: timerController)
                : ExitTestButton(quizState: quizState);
          },
        ),
      ),
      body: PageView.builder(
        physics: const NeverScrollableScrollPhysics(),
        scrollDirection: Axis.vertical,
        controller: quizState.controller,
        onPageChanged: (int idx) =>
            quizState.progress = (idx / (questionQty + 1)),
        itemBuilder: (BuildContext context, int index) {
          if (index == 0) {
            return StartPage(quiz: quiz, timerController: timerController);
          } else if (index == questionQty + 1) {
            if (quizType == QuizType.exam) {
              _stopTimer();
              if (quizState.result) {
                final subjectPositiveKey = '${quizState.subject}_positive';
                final positiveValue =
                    box.get(subjectPositiveKey, defaultValue: 0) as int;
                box.put(subjectPositiveKey, positiveValue + 1);
                return ResultsPage(
                    message: local.congratsMessage, quizState: quizState);
              } else {
                final subjectNegativeKey = '${quizState.subject}_negative';
                final negativeValue =
                    box.get(subjectNegativeKey, defaultValue: 0) as int;
                box.put(subjectNegativeKey, negativeValue + 1);
                return ResultsPage(
                    message: local.failMessage, quizState: quizState);
              }
            } else {
              box.put(quizState.subject, 0);
              return ResultsPage(
                  message: local.congratsMessage, quizState: quizState);
            }
          } else {
            return QuestionPage(question: quizState.questions[index - 1]);
          }
        },
      ),
    );
  }
}

class CloseTestButton extends StatelessWidget {
  const CloseTestButton(
      {Key? key, required this.quizState, required this.timerController})
      : super(key: key);

  final QuizState quizState;
  final CountDownTimerController timerController;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    return IconButton(
      icon: const Icon(FontAwesomeIcons.xmark),
      onPressed: () async {
        final proceed = await showDialog<bool>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text(local.exitQuizTitle),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
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
    );
  }
}

class ExitTestButton extends StatelessWidget {
  const ExitTestButton({Key? key, required this.quizState}) : super(key: key);

  final QuizState quizState;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () async {
        quizState.reset();
        Navigator.pop(context);
      },
    );
  }
}
