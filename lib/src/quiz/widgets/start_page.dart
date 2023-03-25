import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/contdown_timer/countdown_timer.dart';
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
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(quiz.title, style: Theme.of(context).textTheme.headlineMedium),
          if (quiz.id == 'exam')
            Column(
              children: [
                const Divider(),
                Row(
                  children: [
                    const Icon(Icons.list),
                    const SizedBox(width: 10),
                    Text(
                      quiz.questions.length.toString(),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const Spacer(),
                    const Icon(Icons.timer_outlined),
                    const SizedBox(width: 10),
                    Text(
                      '${quiz.time.toString()} min',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const Spacer(),
                    const Icon(Icons.check_circle_outline),
                    const SizedBox(width: 10),
                    Text(
                      '75%',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ],
            ),
          const Divider(),
          Expanded(
              child: Text(
            quiz.description,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.justify,
          )),
          ButtonBar(
            alignment: MainAxisAlignment.center,
            children: <Widget>[
              ElevatedButton(
                // icon: const Icon(Icons.start),
                child: Text(
                  local.startQuizTitle,
                  // style: Theme.of(context).textTheme.titleLarge,
                ),
                onPressed: () {
                  state.nextPage();
                  timerController?.start?.call();
                },
              )
            ],
          )
        ],
      ),
    );
  }
}
