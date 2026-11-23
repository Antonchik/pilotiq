import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/contdown_timer/countdown_timer.dart';
import 'package:pilotiq/src/exams/exam_info_widget.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/progress/providers.dart';
import 'package:pilotiq/src/quiz/quiz_config.dart';
import 'package:pilotiq/src/quiz/state/quiz_state.dart';

class StartPage extends ConsumerWidget {
  final CountDownTimerController? timerController;

  const StartPage({super.key, this.timerController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(quizStateProvider);
    final quiz = state.quiz;
    final local = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(quiz.title, style: Theme.of(context).textTheme.headlineMedium),
          if (quiz.type == QuizType.exam) ExamInfoWidget(spec: quiz.spec),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                quiz.description,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.justify,
              ),
            ),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.start),
            label: Text(local.startQuizTitle, textAlign: TextAlign.center),
            onPressed: () {
              state.startedAt ??= ref.read(clockProvider).now();
              state.nextPage();
              timerController?.start?.call();
            },
          ),
        ],
      ),
    );
  }
}
