import 'package:flutter/material.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';

class ExamInfoWidget extends StatelessWidget {
  const ExamInfoWidget({required this.spec, super.key});

  final ExamSpec spec;

  @override
  Widget build(BuildContext context) {
    final percent = (spec.passRatio * 100).round();
    return Column(
      children: [
        const Divider(),
        Row(
          children: [
            const Icon(Icons.list),
            const SizedBox(width: 10),
            Text(
              spec.quizLength.toString(),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const Spacer(),
            const Icon(Icons.timer_outlined),
            const SizedBox(width: 10),
            Text(
              AppLocalizations.of(context)!.examMinutesShort(spec.minutes),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const Spacer(),
            const Icon(Icons.check_circle_outline),
            const SizedBox(width: 10),
            Text('$percent%', style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ],
    );
  }
}
