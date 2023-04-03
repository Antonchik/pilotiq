import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/models.dart';
import 'package:pilotiq/src/purchases/linkfive_provider.dart';
import 'package:pilotiq/src/purchases/paywall.dart';
import 'package:pilotiq/src/quiz/widgets/quiz_card.dart';

class QuizList extends ConsumerWidget {
  final Subject subject;

  const QuizList({super.key, required this.subject});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    final isPremium = ref.watch(linkFiveProvider).hasActiveProduct;
    final quizzes = composeQuizes(subject, isPremium, local: local);
    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          itemCount: quizzes.length,
          itemBuilder: (BuildContext context, int index) {
            return QuizCard(quiz: quizzes[index]);
          },
        ),
        if (!isPremium)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const Paywall(),
                ),
              ),
              child: Text(local.goPremiumLabel),
            ),
          ),
      ],
    );
  }
}

List<Quiz> composeQuizes(Subject subject, bool isPremium,
    {required AppLocalizations local}) {
  return [
    if (!isPremium)
      Quiz(
        type: QuizType.demo,
        title: local.demoQuizTitle,
        questions: subject.questions.sublist(0, subject.quizLength),
        description: local.demoModeDescription,
      ),
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
