import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pilotiq/src/models.dart';
import 'package:pilotiq/src/quiz/state/quiz_state.dart';
import 'package:pilotiq/src/quiz/widgets/result_scale_bar.dart';

class CongratsPage extends ConsumerWidget {
  final Quiz quiz;
  final QuizState quizState;

  const CongratsPage({super.key, required this.quiz, required this.quizState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    final rightAnswers = quizState.answers.where((e) => e).length;
    final percent = rightAnswers / quiz.questions.length;
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    final children = [
      if (quizState.isExam)
        ResultScaleBar(
          percent: percent,
          header: '$rightAnswers/${quiz.questions.length}',
        )
      else
        Column(
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
        ),
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            local.congratsMessage,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Divider(),
          ElevatedButton(
            child: Text(local.returnToSubjectTitle),
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
