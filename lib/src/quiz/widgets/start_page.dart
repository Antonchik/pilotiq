import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/contdown_timer/countdown_timer.dart';
import 'package:pilotiq/src/exams/exam_info_widget.dart';
import 'package:pilotiq/src/hive_box_provider.dart';
import 'package:pilotiq/src/models.dart';
import 'package:pilotiq/src/quiz/state/quiz_state.dart';

class StartPage extends ConsumerWidget {
  final Quiz quiz;
  final CountDownTimerController? timerController;

  const StartPage({super.key, required this.quiz, this.timerController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var state = ref.watch(quizStateProvider);
    final local = AppLocalizations.of(context)!;
    final firstQuestionIndex = ref.read(hiveBoxProvider).get(
          quiz.subject,
          defaultValue: 0,
        );
    final isRestartable = !state.isExam && firstQuestionIndex > 0;
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(quiz.title, style: Theme.of(context).textTheme.headlineMedium),
          if (quiz.type == QuizType.exam) ExamInfoWidget(quiz: quiz),
          const Divider(),
          Expanded(
              child: Text(
            quiz.description,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.justify,
          )),
          if (isRestartable)
            Text(
              local.restartMessage,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ButtonBar(
            alignment: MainAxisAlignment.center,
            children: <ElevatedButton>[
              ElevatedButton.icon(
                icon: const Icon(Icons.start),
                label: SizedBox(
                  width: 80,
                  child: Text(
                    isRestartable
                        ? local.startNewQuizTitle
                        : local.startQuizTitle,
                    textAlign: TextAlign.center,
                  ),
                ),
                onPressed: () {
                  if (!state.isExam) {
                    ref.read(hiveBoxProvider).put(state.subject, 0);
                  }
                  state.nextPage();
                  timerController?.start?.call();
                },
              ),
              if (isRestartable)
                ElevatedButton.icon(
                  icon: const Icon(Icons.navigate_next),
                  label: SizedBox(
                    width: 80,
                    child: Text(
                      local.continueQuizTitle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  onPressed: () {
                    state.continueFromPage(firstQuestionIndex);
                    timerController?.start?.call();
                  },
                ),
            ],
          )
        ],
      ),
    );
  }
}
