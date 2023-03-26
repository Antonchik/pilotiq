import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pilotiq/src/models.dart';
import 'package:pilotiq/src/quiz/state/quiz_state.dart';
import 'package:pilotiq/src/quiz/widgets/result_scale_bar.dart';

class FailPage extends StatelessWidget {
  final Quiz quiz;
  final QuizState quizState;

  const FailPage({super.key, required this.quiz, required this.quizState});

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final rightAnswers = quizState.answers.where((e) => e).length;
    final percent = rightAnswers / quiz.questions.length;
    final isPortrait = MediaQuery.of(context).orientation.name == 'portrait';
    final children = [
      ResultScaleBar(
        percent: percent,
        header: '$rightAnswers/${quiz.questions.length}',
      ),
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            local.failMessage(quiz.title),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Divider(),
          ElevatedButton.icon(
            style: TextButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
            ),
            icon: const Icon(FontAwesomeIcons.faceFrown),
            label: Text(local.returnToSubjectTitle),
            onPressed: () {
              quizState.reset();
              Navigator.pop(context);
            },
          )
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
