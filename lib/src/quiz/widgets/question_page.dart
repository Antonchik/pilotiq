import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pilotiq/src/models.dart';
import 'package:pilotiq/src/quiz/state/quiz_state.dart';

class QuestionPage extends ConsumerWidget {
  final Question question;

  const QuestionPage({super.key, required this.question});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var state = ref.watch(quizStateProvider);
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          // alignment: Alignment.center,
          child: SingleChildScrollView(
            child: Text(question.question.split('\n').last,
                textAlign: TextAlign.justify,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge!
                    .copyWith(fontWeight: FontWeight.bold)),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: question.answers.map((answer) {
                  return Container(
                    constraints: const BoxConstraints(minHeight: 60),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                        color: Theme.of(context).hoverColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Theme.of(context).highlightColor, width: 2)),
                    child: InkWell(
                      onTap: () {
                        state.selected = answer;
                        if (state.isExam) {
                          state.answer = answer.isCorrect;
                          state.nextPage();
                        } else {
                          _bottomSheet(context, answer, state);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                                state.selected == answer
                                    ? FontAwesomeIcons.circleCheck
                                    : FontAwesomeIcons.circle,
                                size: 20),
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.only(left: 12),
                                child: Text(
                                  answer.value.split('\n').last,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        )
      ],
    );
  }

  _bottomSheet(BuildContext context, Answer opt, QuizState state) {
    bool correct = opt.isCorrect;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      // barrierColor: correct
      //     ? Colors.green.withOpacity(0.3)
      //     : Theme.of(context).primaryColor.withOpacity(0.3),
      builder: (BuildContext context) {
        final local = AppLocalizations.of(context)!;
        return Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // Icon(
              //   correct
              //       ? FontAwesomeIcons.faceSmile
              //       : FontAwesomeIcons.faceFrown,
              //   size: 50,
              //   color: correct ? Colors.green : Colors.red,
              // ),
              Text(
                correct ? local.rightAnswer : local.wrongAnswer,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: correct ? Colors.green : Colors.red),
                child: Text(
                  correct ? local.nextQuestion : local.tryAgain,
                  style: const TextStyle(
                    color: Colors.white,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  if (correct) {
                    state.nextPage();
                  }
                  state.answer = correct;
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
