import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pilotiq/src/models.dart';
import 'package:pilotiq/src/quiz/widgets/quiz_card.dart';

class QuizList extends StatelessWidget {
  final Subject subject;

  const QuizList({super.key, required this.subject});

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final quizzes = composeQuizes(subject, local: local);
    return ListView.builder(
      shrinkWrap: true,
      itemCount: quizzes.length,
      itemBuilder: (BuildContext context, int index) {
        return QuizCard(quiz: quizzes[index]);
      },
    );
  }
}

List<Quiz> composeQuizes(Subject subject, {required AppLocalizations local}) {
  final questions = subject.questions;
  return [
    // Quiz(
    //   id: 'demo',
    //   title: local.demoQuizTitle,
    //   questions: questions.sublist(0, subject.quizLength),
    //   description: local.demoModeDescription,
    // ),
    Quiz(
      id: 'test',
      title: local.fullQuizTitle,
      questions: questions.toList(),
      description: local.fullModeDescription,
    ),
    Quiz(
      id: 'exam',
      title: local.examQuizTitle,
      questions: (questions.toList()..shuffle()).sublist(0, subject.quizLength),
      time: subject.examTime,
      description: local.examModeDescription,
    ),
  ];
}
