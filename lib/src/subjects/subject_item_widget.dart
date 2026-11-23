import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/quiz/practice/practice_controller.dart';
import 'package:pilotiq/src/subjects/subject_info.dart';
import 'package:pilotiq/src/subjects/subject_screen.dart';

/// A subject in the list: cover, title, question count and the progress of
/// the user (coverage bar and accuracy).
class SubjectItem extends ConsumerWidget {
  final SubjectInfo subject;

  const SubjectItem({super.key, required this.subject});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    final key = (licence: subject.licence, subject: subject.id);
    final stats = ref.watch(subjectStatsProvider(key)).value;
    return Card(
      key: Key('subject_${subject.id.id}'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) =>
                  SubjectScreen(subject: subject),
            ),
          );
          ref.invalidate(subjectStatsProvider(key));
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 90),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: Hero(
                    tag: '${subject.licence.id}_${subject.id.id}',
                    child: Image.asset(
                      'assets/covers/${subject.image}',
                      fit: BoxFit.fitHeight,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
                Flexible(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject.title,
                          style: const TextStyle(
                            height: 1.2,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        Text(
                          local.subjectQuestionCount(subject.questions.length),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (stats != null) ...[
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: stats.coverage,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            stats.hasAnswers
                                ? '${local.practiceSubjectCoverage((stats.coverage * 100).round())} · '
                                      '${local.practiceSubjectAccuracy((stats.accuracy * 100).round())}'
                                : local.practiceSubjectNotStarted,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
