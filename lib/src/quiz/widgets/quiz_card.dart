import 'package:flutter/material.dart';
import 'package:pilotiq/src/models.dart';
import 'package:pilotiq/src/quiz/quiz.dart';

class QuizCard extends StatelessWidget {
  const QuizCard({Key? key, required this.quiz}) : super(key: key);

  final Quiz quiz;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(4),
      child: InkWell(
        onTap: () {
          if (quiz.type == QuizType.exam) {
            quiz.questions.shuffle();
          }
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (BuildContext context) => QuizScreen(
                quizType: quiz.type,
                quiz: quiz,
              ),
            ),
          );
        },
        child: Container(
          color: Theme.of(context).colorScheme.surface,
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
  }
}
