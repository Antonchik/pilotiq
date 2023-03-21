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
              ElevatedButton.icon(
                onPressed: () {
                  state.nextPage();
                  timerController?.start?.call();
                },
                label: Text(
                  local.startQuizTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                icon: const Icon(Icons.checklist),
              )
            ],
          )
        ],
      ),
    );
  }
}
