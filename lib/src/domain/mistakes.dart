import 'package:pilotiq/src/progress/question_progress.dart';

/// A question is a "mistake" until it has been answered correctly twice in a
/// row after the last wrong answer.
bool isMistake(QuestionProgress p) => p.wrong > 0 && p.consecutiveCorrect < 2;

/// Ids of the questions that are currently mistakes.
List<String> mistakeIds(Iterable<QuestionProgress> all) =>
    [for (final p in all) if (isMistake(p)) p.qid];
