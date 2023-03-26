import 'package:flutter/material.dart';
import 'package:pilotiq/src/models.dart';
import 'package:pilotiq/src/quiz/quiz.dart';

class QuizCard extends StatelessWidget {
  const QuizCard({Key? key, required this.quiz}) : super(key: key);

  final Quiz quiz;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
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
  }
}
