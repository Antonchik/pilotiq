import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:pilotiq/src/bank/licence_provider.dart';
import 'package:pilotiq/src/contdown_timer/countdown_timer.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/progress/exam_attempt.dart';
import 'package:pilotiq/src/progress/providers.dart';
import 'package:pilotiq/src/quiz/quiz_config.dart';
import 'package:pilotiq/src/quiz/state/quiz_state.dart';
import 'package:pilotiq/src/quiz/widgets/question_page.dart';
import 'package:pilotiq/src/quiz/widgets/results_page.dart';
import 'package:pilotiq/src/quiz/widgets/start_page.dart';

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key, required this.quiz});

  final Quiz quiz;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  final timerController = CountDownTimerController();

  @override
  void initState() {
    super.initState();
    ref
        .read(quizStateProvider)
        .configure(
          widget.quiz,
          ref.read(effectiveQuestionLanguageProvider(widget.quiz.licence)),
        );
  }

  void _stopTimer() => timerController.pause?.call();

  /// Called once when the results page is reached: stops the timer and stores
  /// the exam attempt.
  void _finish(QuizState state) {
    if (state.finished) return;
    state.finished = true;
    _stopTimer();
    if (!state.isExam) return;
    final quiz = widget.quiz;
    final score = state.score;
    final finishedAt = ref.read(clockProvider).now();
    final startedAt = state.startedAt ?? finishedAt;
    final attempt = ExamAttempt(
      id: '${startedAt.microsecondsSinceEpoch}-${quiz.licence.id}-${quiz.subject.id}',
      licence: quiz.licence,
      subject: quiz.subject,
      startedAt: startedAt,
      finishedAt: finishedAt,
      durationSec: finishedAt.difference(startedAt).inSeconds,
      total: score.total,
      correct: score.correct,
      passed: score.passed,
      reason: AttemptReason.finished,
      questionIds: [for (final q in quiz.questions) q.id],
      answers: {for (final a in state.answers) a.question.id: a.canonicalIndex},
      topicBreakdown: score.topicBreakdown,
    );
    unawaited(
      ref
          .read(progressRepositoryProvider)
          .saveAttempt(attempt)
          .then<void>(
            (_) {},
            onError: (Object e) => debugPrint('Could not save attempt: $e'),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final quiz = widget.quiz;
    final quizState = ref.read(quizStateProvider);
    // Keeps the (auto-disposed) state alive while the screen is shown.
    ref.listen(quizStateProvider, (_, _) {});
    final questionQty = quiz.questions.length;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Consumer(
              builder: (BuildContext context, WidgetRef ref, Widget? child) {
                final quizState = ref.watch(quizStateProvider);
                final currentQuestion = (quizState.progress * questionQty)
                    .ceil()
                    .clamp(0, questionQty);
                return LinearPercentIndicator(
                  lineHeight: 5,
                  barRadius: const Radius.circular(10),
                  percent: questionQty == 0 ? 0 : currentQuestion / questionQty,
                  animation: true,
                  animationDuration: 750,
                  animateFromLastPercent: true,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  progressColor: Theme.of(context).colorScheme.onPrimary,
                  leading: SizedBox(
                    width: 45,
                    child: Text(
                      '$currentQuestion/$questionQty',
                      style: TextStyle(
                        fontSize: 16.0,
                        color: Theme.of(context).colorScheme.inversePrimary,
                      ),
                    ),
                  ),
                  trailing: SizedBox(
                    width: 65,
                    child: quiz.type == QuizType.exam
                        ? CountDownTimer(
                            controller: timerController,
                            durationInMinutes: quiz.spec.minutes,
                          )
                        : null,
                  ),
                );
              },
            ),
          ],
        ),
        leading: Consumer(
          builder: (BuildContext context, WidgetRef ref, Widget? child) {
            final quizState = ref.watch(quizStateProvider);
            if (quizState.finished) return const SizedBox.shrink();
            return quizState.progress > 0
                ? CloseTestButton(timerController: timerController)
                : const ExitTestButton();
          },
        ),
      ),
      body: PageView.builder(
        physics: const NeverScrollableScrollPhysics(),
        scrollDirection: Axis.vertical,
        controller: quizState.controller,
        itemCount: questionQty + 2,
        onPageChanged: (int idx) {
          quizState.progress = idx / (questionQty + 1);
          if (idx == questionQty + 1) _finish(quizState);
        },
        itemBuilder: (BuildContext context, int index) {
          if (index == 0) {
            return StartPage(timerController: timerController);
          } else if (index == questionQty + 1) {
            final message = quiz.type == QuizType.exam && !quizState.result
                ? local.failMessage
                : local.congratsMessage;
            return ResultsPage(message: message);
          } else {
            return QuestionPage(
              key: ValueKey(quiz.questions[index - 1].id),
              question: quiz.questions[index - 1],
            );
          }
        },
      ),
    );
  }
}

class CloseTestButton extends StatelessWidget {
  const CloseTestButton({super.key, required this.timerController});

  final CountDownTimerController timerController;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    return IconButton(
      icon: const Icon(Icons.close),
      onPressed: () async {
        final proceed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
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
          },
        );
        if (proceed ?? false) {
          timerController.reset?.call();
          if (context.mounted) {
            Navigator.pop(context);
          }
        }
      },
    );
  }
}

class ExitTestButton extends StatelessWidget {
  const ExitTestButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => Navigator.pop(context),
    );
  }
}
