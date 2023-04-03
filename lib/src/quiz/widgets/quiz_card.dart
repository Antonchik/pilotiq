import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/models.dart';
import 'package:pilotiq/src/purchases/linkfive_provider.dart';
import 'package:pilotiq/src/quiz/quiz.dart';

class QuizCard extends ConsumerWidget {
  const QuizCard({Key? key, required this.quiz}) : super(key: key);

  final Quiz quiz;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(linkFiveProvider).hasActiveProduct;
    final unlocked = isPremium || quiz.type == QuizType.demo;
    return Card(
      margin: const EdgeInsets.all(4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        enabled: unlocked,
        trailing: unlocked ? null : const Icon(Icons.lock_outline),
        title: Text(quiz.title),
        subtitle: Text(
          quiz.description,
          textAlign: TextAlign.justify,
        ),
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
      ),
    );
  }
}
