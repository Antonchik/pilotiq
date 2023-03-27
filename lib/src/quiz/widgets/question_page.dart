import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/models.dart';
import 'package:pilotiq/src/quiz/state/quiz_state.dart';
import 'package:pilotiq/src/quiz/widgets/answer_card.dart';

class QuestionPage extends ConsumerWidget {
  final Question question;

  const QuestionPage({super.key, required this.question});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var state = ref.watch(quizStateProvider);
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Text(question.question.split('\n').last,
                textAlign: TextAlign.justify,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge!
                    .copyWith(fontWeight: FontWeight.bold)),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: ListView.builder(
              itemCount: question.answers.length,
              itemBuilder: (context, index) {
                final opt = question.answers[index];
                return AnswerCard(option: opt, state: state);
              },
            ),
          ),
        )
      ],
    );
  }
}
