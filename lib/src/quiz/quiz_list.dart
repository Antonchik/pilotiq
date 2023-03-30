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
  return [
    // Quiz(
    //   type: QuizType.demo,
    //   title: local.demoQuizTitle,
    //   questions: subject.questions.sublist(0, subject.quizLength),
    //   description: local.demoModeDescription,
    // ),
    Quiz(
      type: QuizType.all,
      title: local.fullQuizTitle,
      subject: subject.id,
      questions: subject.questions.toList(),
      description: local.fullModeDescription,
    ),
    Quiz(
      type: QuizType.exam,
      title: local.examQuizTitle,
      subject: subject.id,
      questions: subject.questions.toList(),
      time: subject.examTime,
      length: subject.quizLength,
      description: local.examModeDescription,
    ),
  ];
}
