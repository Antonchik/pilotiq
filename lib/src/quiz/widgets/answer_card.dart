import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pilotiq/src/hive_box_provider.dart';
import 'package:pilotiq/src/models.dart';
import 'package:pilotiq/src/quiz/state/quiz_state.dart';

class AnswerCard extends ConsumerWidget {
  const AnswerCard({Key? key, required this.option, required this.state})
      : super(key: key);

  final Answer option;
  final QuizState state;

  void _bottomSheet(
      BuildContext context, WidgetRef ref, Answer opt, QuizState state) {
    bool correct = opt.isCorrect;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (BuildContext context) {
        final local = AppLocalizations.of(context)!;
        return Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text(
                correct ? local.rightAnswer : local.wrongAnswer,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: correct ? Colors.green : Colors.red),
                child: Text(
                  correct ? local.nextQuestion : local.tryAgain,
                  style: const TextStyle(
                    color: Colors.white,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  // if (correct) {
                  //   ref
                  //       .read(hiveBoxProvider)
                  //       .put(state.subject, state.controller.page!.toInt() + 1);
                  //   state.nextPage();
                  // }
                  // state.answer = correct;
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedColor = option.isCorrect ? Colors.green : Colors.red;
    final rightSelected = !state.isExam && state.selected == option;
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: rightSelected
                  ? selectedColor
                  : Theme.of(context).colorScheme.outlineVariant,
              width: rightSelected ? 2 : 1)),
      child: InkWell(
        onTap: () {
          state.selected = option;
          if (state.isExam) {
            state.answer = option.isCorrect;
            HapticFeedback.lightImpact();
            state.nextPage();
          } else {
            if (option.isCorrect) {
              // HapticFeedback.mediumImpact();
              HapticFeedback.heavyImpact();
              ref
                  .read(hiveBoxProvider)
                  .put(state.subject, state.controller.page!.toInt() + 1);
              Future.delayed(const Duration(milliseconds: 500))
                  .then((value) => state.nextPage());
            } else {
              // HapticFeedback.heavyImpact();
              HapticFeedback.vibrate();
              _bottomSheet(context, ref, option, state);
            }
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Icon(
                  state.selected == option
                      ? FontAwesomeIcons.circleCheck
                      : FontAwesomeIcons.circle,
                  size: 20),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(left: 12),
                  child: Text(
                    option.value.split('\n').last,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
