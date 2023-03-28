import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/models.dart';
import 'package:pilotiq/src/quiz/state/quiz_state.dart';
import 'package:pilotiq/src/quiz/widgets/result_scale_bar.dart';
import 'package:pilotiq/src/quiz/widgets/review_answers_page.dart';

class FailPage extends ConsumerWidget {
  final Quiz quiz;
  final QuizState quizState;

  const FailPage({super.key, required this.quiz, required this.quizState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    final rightAnswers = quizState.answers.where((e) => e.isCorrect).length;
    final percent = rightAnswers / quiz.questions.length;
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final children = [
      ResultScaleBar(
        percent: percent,
        header: '$rightAnswers/${quiz.questions.length}',
      ),
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            local.failMessage,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Divider(),
          ElevatedButton.icon(
            icon: const Icon(Icons.arrow_back),
            label: Text(local.returnToSubjectTitle),
            onPressed: () {
              quizState.reset();
              Navigator.pop(context);
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.checklist),
            label: Text(local.reviewAnswersTitle),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        ReviewAnswersPage(quizState: quizState)),
              );
            },
          ),
        ],
      ),
    ];
    return Padding(
      padding: const EdgeInsets.all(8),
      child: isPortrait
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: children,
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: children,
            ),
    );
  }
}
