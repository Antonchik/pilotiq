import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/domain/exam_builder.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/progress/providers.dart';
import 'package:pilotiq/src/quiz/quiz.dart';
import 'package:pilotiq/src/quiz/quiz_config.dart';
import 'package:pilotiq/src/subjects/subject_info.dart';

/// Temporary entry point of the exam simulation: it draws a fresh stratified
/// sample of the subject (one variant per NUMER) and opens the classic quiz
/// screen in exam mode. The exam step replaces this file with the real one.
Future<void> openExamSimulation(
  BuildContext context,
  WidgetRef ref,
  SubjectInfo subject,
) {
  final local = AppLocalizations.of(context)!;
  final byId = {for (final q in subject.questions) q.id: q};
  final picked = ExamBuilder.build(
    [
      for (final q in subject.questions)
        ExamCandidate(id: q.id, number: q.number, topic: q.topic),
    ],
    subject.spec,
    ref.read(randomProvider),
  );
  final quiz = Quiz(
    type: QuizType.exam,
    title: local.examQuizTitle,
    description: local.examModeDescription,
    licence: subject.licence,
    subject: subject.id,
    questions: [for (final c in picked) byId[c.id]!],
    spec: subject.spec,
  );
  return Navigator.of(
    context,
  ).push<void>(MaterialPageRoute<void>(builder: (_) => QuizScreen(quiz: quiz)));
}
