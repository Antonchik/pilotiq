import 'package:pilotiq/src/bank/models.dart';
import 'package:pilotiq/src/domain/catalog.dart';

enum QuizType { all, exam }

/// What the quiz screen is asked to run.
class Quiz {
  const Quiz({
    required this.type,
    required this.title,
    required this.description,
    required this.licence,
    required this.subject,
    required this.questions,
    required this.spec,
  });

  final QuizType type;
  final String title;
  final String description;
  final Licence licence;
  final SubjectId subject;
  final List<Question> questions;
  final ExamSpec spec;
}
