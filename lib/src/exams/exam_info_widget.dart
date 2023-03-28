import 'package:flutter/material.dart';
import 'package:pilotiq/src/models.dart';

class ExamInfoWidget extends StatelessWidget {
  const ExamInfoWidget({required this.quiz, Key? key}) : super(key: key);

  final Quiz quiz;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(),
        Row(
          children: [
            const Icon(Icons.list),
            const SizedBox(width: 10),
            Text(
              quiz.questions.length.toString(),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const Spacer(),
            const Icon(Icons.timer_outlined),
            const SizedBox(width: 10),
            Text(
              '${quiz.time.toString()} min',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const Spacer(),
            const Icon(Icons.check_circle_outline),
            const SizedBox(width: 10),
            Text(
              '75%',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ],
    );
  }
}
