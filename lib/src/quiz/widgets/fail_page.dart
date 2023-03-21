import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pilotiq/src/models.dart';
import 'package:pilotiq/src/quiz/state/quiz_state.dart';

class FailPage extends StatelessWidget {
  final Quiz quiz;
  final QuizState quizState;

  const FailPage({super.key, required this.quiz, required this.quizState});

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            local.failMessage(quiz.title),
            textAlign: TextAlign.center,
          ),
          const Divider(),
          ElevatedButton.icon(
            style: TextButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            icon: const Icon(FontAwesomeIcons.faceFrown),
            label: Text(local.returnToTopicTitle),
            onPressed: () {
              quizState.reset();
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/',
                (route) => false,
              );
            },
          )
        ],
      ),
    );
  }
}
