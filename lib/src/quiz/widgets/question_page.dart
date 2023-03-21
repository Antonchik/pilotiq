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
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';
    final curQuestion = question.question.split('\n');
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            child: Text(isEnglish ? curQuestion.last : curQuestion.first,
                style: Theme.of(context).textTheme.bodyLarge),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: question.answers.map((answer) {
              final curAnswer = answer.value.split('\n');
              return Container(
                height: 90,
                margin: const EdgeInsets.only(bottom: 10),
                color: Colors.black26,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                              isEnglish ? curAnswer.last : curAnswer.first,
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
        )
      ],
    );
  }

  _bottomSheet(BuildContext context, Answer opt, QuizState state) {
    bool correct = opt.isCorrect;

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        final local = AppLocalizations.of(context)!;
        return Container(
          height: 250,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text(correct ? local.rightAnswer : local.wrongAnswer),
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
