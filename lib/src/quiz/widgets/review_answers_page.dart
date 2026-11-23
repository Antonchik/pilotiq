import 'package:flutter/material.dart';
import 'package:pilotiq/src/bank/bank_text.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/quiz/state/quiz_state.dart';

class ReviewAnswersPage extends StatelessWidget {
  const ReviewAnswersPage({super.key, required this.quizState});

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
          final question = answer.question;
          final language = question.displayLanguage(quizState.language);
          return Card(
            child: Container(
              alignment: Alignment.topLeft,
              constraints: const BoxConstraints(minHeight: 100),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.only(left: 12),
                    child: answer.isCorrect
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.cancel, color: Colors.red),
                  ),
                  Expanded(
                    child: ListTile(
                      title: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${index + 1}. '),
                          Expanded(
                            child: BankText(
                              question.text.resolve(language),
                              textAlign: TextAlign.justify,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!answer.isCorrect)
                            BankText(
                              question.answers[answer.canonicalIndex].resolve(
                                language,
                              ),
                              textAlign: TextAlign.justify,
                              style: Theme.of(context).textTheme.bodySmall!
                                  .copyWith(
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: Colors.red,
                                    decorationThickness: 2,
                                    color: Colors.red,
                                  ),
                            ),
                          BankText(
                            question.answers[question.correctIndex].resolve(
                              language,
                            ),
                            textAlign: TextAlign.justify,
                            style: Theme.of(context).textTheme.bodySmall!
                                .copyWith(color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
