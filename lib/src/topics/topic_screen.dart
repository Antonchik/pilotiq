import 'package:flutter/material.dart';
import 'package:pilotiq/src/quiz/quiz.dart';
import 'package:pilotiq/src/topics/topic_model.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class TopicScreen extends StatelessWidget {
  final Topic topic;

  const TopicScreen({super.key, required this.topic});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
      ),
      body: ListView(children: [
        Hero(
          tag: topic.id,
          child: Image.asset('assets/covers/${topic.img}',
              width: MediaQuery.of(context).size.width),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(topic.title,
              style: const TextStyle(
                  height: 2,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  overflow: TextOverflow.fade)),
        ),
        QuizList(topic: topic),
      ]),
    );
  }
}

class QuizList extends StatelessWidget {
  final Topic topic;

  const QuizList({super.key, required this.topic});

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final quizzes = composeQuizes(topic.questions, local: local);
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
