import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/bank/question_bank_repository.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/subjects/subject_info.dart';
import 'package:pilotiq/src/subjects/subject_item_widget.dart';

/// The subjects of [licence], built from its question bank. Subjects without
/// questions are hidden.
class SubjectListBuilder extends ConsumerWidget {
  const SubjectListBuilder({super.key, required this.licence});

  final Licence licence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    final bank = ref.watch(bankProvider(licence));
    return bank.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(local.bankLoadError),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => ref.invalidate(bankProvider(licence)),
              child: Text(local.bankRetryLabel),
            ),
          ],
        ),
      ),
      data: (bank) {
        final subjects = [
          for (final id in bank.subjects)
            SubjectInfo(
              licence: licence,
              id: id,
              title: subjectTitle(local, id),
              description: subjectDescription(local, id),
              spec: ExamSpec.forSubject(id, licence: licence),
              questions: bank.questionsOf(id),
            ),
        ];
        return ListView.builder(
          itemCount: subjects.length,
          itemBuilder: (context, index) =>
              SubjectItem(subject: subjects[index]),
        );
      },
    );
  }
}
