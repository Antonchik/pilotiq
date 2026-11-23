import 'package:flutter/material.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/quiz/state/quiz_state.dart';

class ReviewAnswersPage extends StatelessWidget {
  const ReviewAnswersPage({
    Key? key,
    required this.quizState,
  }) : super(key: key);

  final QuizState quizState;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.reviewAnswersTitle),
        ),
        body: ListView.builder(
          itemCount: quizState.answers.length,
          itemBuilder: (context, index) {
            final answer = quizState.answers[index];
            final question = quizState.questions[index];
            return Card(
              child: Container(
                alignment: Alignment.topLeft,
                constraints: const BoxConstraints(minHeight: 100),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.only(left: 12),
                      child: answer.isCorrect
                          ? const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                            )
                          : const Icon(
                              Icons.cancel,
                              color: Colors.red,
                            ),
                    ),
                    Expanded(
                      child: ListTile(
                        title: Text(
                          '${index + 1}. ${question.question}',
                          textAlign: TextAlign.justify,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!answer.isCorrect)
                              Text(
                                answer.value.trim(),
                                textAlign: TextAlign.justify,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall!
                                    .copyWith(
                                      decoration: TextDecoration.lineThrough,
                                      decorationColor: Colors.red,
                                      decorationThickness: 2,
                                      color: Colors.red,
                                    ),
                              ),
                            Text(
                              question.answers
                                  .singleWhere((element) => element.isCorrect)
                                  .value,
                              textAlign: TextAlign.justify,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall!
                                  .copyWith(
                                    color: Colors.green,
                                  ),
                            ),
                          ],
                        ),
                        // trailing: answer.isCorrect
                        //     ? const Icon(Icons.check_circle, color: Colors.green)
                        //     : const Icon(Icons.cancel, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ));
  }
}
