import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pilotiq/src/models.dart';
import 'package:pilotiq/src/quiz/quiz.dart';

class QuizList extends StatelessWidget {
  final Topic topic;

  const QuizList({super.key, required this.topic});

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final quizzes = composeQuizes(topic, local: local);
    return Column(
      children: quizzes.map(
        (quiz) {
          return Card(
            shape:
                const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            elevation: 4,
            margin: const EdgeInsets.all(4),
            child: InkWell(
              onTap: () {
                quiz.questions.shuffle();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (BuildContext context) => QuizScreen(
                      quizId: quiz.id,
                      quiz: quiz,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(
                    quiz.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  subtitle: Text(
                    quiz.description,
                    overflow: TextOverflow.fade,
                    style: Theme.of(context).textTheme.titleSmall,
                    textAlign: TextAlign.justify,
                  ),
                ),
              ),
            ),
          );
        },
      ).toList(),
    );
  }
}

List<Quiz> composeQuizes(Topic topic, {required AppLocalizations local}) {
  final questions = topic.questions;
  final demoQuestions = questions.sublist(0, topic.quizLength);
  final allQuestions = questions.toList();
  final examQuestions =
      (questions.toList()..shuffle()).sublist(0, topic.quizLength);
  return [
    // Quiz(
    //   id: 'demo',
    //   title: local.demoQuizTitle,
    //   questions: demoQuestions,
    //   description: local.demoModeDescription,
    // ),
    Quiz(
      id: 'test',
      title: local.fullQuizTitle,
      questions: allQuestions,
      description: local.fullModeDescription,
    ),
    Quiz(
      id: 'exam',
      title: local.examQuizTitle,
      questions: examQuestions,
      time: topic.examTime,
      description: local.examModeDescription,
    ),
  ];
}
