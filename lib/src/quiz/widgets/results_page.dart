import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pilotiq/src/quiz/state/quiz_state.dart';
import 'package:pilotiq/src/quiz/widgets/result_scale_bar.dart';
import 'package:pilotiq/src/quiz/widgets/review_answers_page.dart';

class ResultsPage extends ConsumerWidget {
  const ResultsPage({
    super.key,
    required this.message,
    required this.quizState,
  });

  final QuizState quizState;
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    final rightAnswers = quizState.answers.where((e) => e.isCorrect).length;
    final percent = rightAnswers / quizState.questions.length;
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final children = [
      if (quizState.isExam)
        ResultScaleBar(
          percent: percent,
          header: '$rightAnswers/${quizState.questions.length}',
        )
      else
        const AllQuestionsCompleteWidget(),
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            message,
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

class AllQuestionsCompleteWidget extends StatelessWidget {
  const AllQuestionsCompleteWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Center(
          child: Icon(
            FontAwesomeIcons.circleCheck,
            size: 100,
            color: Colors.green,
          ),
        ),
        SizedBox(
          height: 20,
        ),
      ],
    );
  }
}
