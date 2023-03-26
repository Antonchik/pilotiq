import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:pilotiq/src/models.dart';
import 'package:pilotiq/src/quiz/state/quiz_state.dart';

class CongratsPage extends StatelessWidget {
  final Quiz quiz;
  final QuizState quizState;

  const CongratsPage({super.key, required this.quiz, required this.quizState});

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final rightAnswers = quizState.answers.where((e) => e).length;
    final percent = rightAnswers / quiz.questions.length;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularPercentIndicator(
              radius: 100.0,
              lineWidth: 15.0,
              percent: percent,
              center: Text('${(percent * 100).round()}%',
                  style: Theme.of(context).textTheme.headlineMedium),
              progressColor: Colors.green,
              arcBackgroundColor: Theme.of(context).primaryColor,
              arcType: ArcType.HALF,
              circularStrokeCap: CircularStrokeCap.butt,
              animation: true,
              animationDuration: 3000,
              rotateLinearGradient: true,
              footer: Text(
                '$rightAnswers/${quiz.questions.length}',
                style: Theme.of(context).textTheme.headlineSmall,
              )),
          const SizedBox(height: 50),
          Text(
            local.congratsMessage(quiz.title),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Divider(),
          ElevatedButton.icon(
            style: TextButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            icon: const Icon(FontAwesomeIcons.faceSmile),
            label: Text(local.returnToTopicTitle),
            onPressed: () {
              quizState.reset();
              Navigator.pop(context);
              // Navigator.pushNamedAndRemoveUntil(
              //   context,
              //   '/',
              //   (route) => false,
              // );
            },
          )
        ],
      ),
    );
  }
}
