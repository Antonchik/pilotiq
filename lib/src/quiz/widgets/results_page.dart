import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/quiz/state/quiz_state.dart';
import 'package:pilotiq/src/quiz/widgets/result_scale_bar.dart';
import 'package:pilotiq/src/quiz/widgets/review_answers_page.dart';

class ResultsPage extends ConsumerWidget {
  const ResultsPage({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    final quizState = ref.watch(quizStateProvider);
    final score = quizState.isExam ? quizState.score : null;
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final children = [
      if (score != null)
        ResultScaleBar(
          percent: score.ratio,
          header: '${score.correct}/${score.total}',
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
            onPressed: () => Navigator.pop(context),
          ),
          if (quizState.isExam)
            ElevatedButton.icon(
              icon: const Icon(Icons.checklist),
              label: Text(local.reviewAnswersTitle),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) =>
                        ReviewAnswersPage(quizState: quizState),
                  ),
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
  const AllQuestionsCompleteWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Center(child: Icon(Icons.check_circle, size: 100, color: Colors.green)),
        SizedBox(height: 20),
      ],
    );
  }
}
