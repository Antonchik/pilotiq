import 'dart:math';

import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/progress/user_settings.dart';

/// A text of the bank in Polish and, when the source has it, in English.
class LocalizedText {
  const LocalizedText({required this.pl, this.en});

  final String pl;

  /// English translation; `null` (or blank) when the source has none.
  final String? en;

  bool get hasEnglish => en != null && en!.trim().isNotEmpty;

  /// Text in [language]; English falls back to Polish when missing.
  String resolve(QuestionLanguage language) =>
      language == QuestionLanguage.en && hasEnglish ? en! : pl;

  factory LocalizedText.fromJson(Object? json) {
    if (json is! Map || json['pl'] is! String) {
      throw FormatException('Invalid localized text: $json');
    }
    final en = json['en'];
    return LocalizedText(
      pl: json['pl'] as String,
      en: en is String ? en : null,
    );
  }
}

/// One exam question. Answers are kept in the canonical order of the bank
/// (the correct one is [correctIndex], always 0 in the current banks); they
/// are shuffled only when shown, see [shuffledAnswers].
class Question {
  const Question({
    required this.id,
    required this.number,
    required this.topic,
    required this.subject,
    required this.text,
    required this.answers,
    required this.correctIndex,
  });

  /// Stable id (`PL010-0001`, or `PL010-0001~ab12cd` for variants).
  final String id;

  /// Normalised NUMER; variants of one question share it.
  final String number;

  /// Topic prefix, e.g. `PL010`.
  final String topic;
  final SubjectId subject;
  final LocalizedText text;
  final List<LocalizedText> answers;
  final int correctIndex;

  /// True when the question and **every** answer have an English text.
  bool get hasFullEnglish =>
      text.hasEnglish && answers.every((a) => a.hasEnglish);

  /// The language the question is really shown in. When English is requested
  /// but at least one answer lacks a translation, the whole question is shown
  /// in Polish so that the answers look uniform and the correct one does not
  /// stand out.
  QuestionLanguage displayLanguage(QuestionLanguage requested) =>
      requested == QuestionLanguage.en && hasFullEnglish
      ? QuestionLanguage.en
      : QuestionLanguage.pl;

  factory Question.fromJson(Map<String, dynamic> json) {
    final subject = SubjectId.fromId(json['subject'] as String?);
    final answers = json['a'];
    final correct = json['correct'];
    if (json['id'] is! String ||
        json['number'] is! String ||
        json['topic'] is! String ||
        subject == null ||
        answers is! List ||
        answers.length != 4 ||
        correct is! int ||
        correct < 0 ||
        correct > 3) {
      throw FormatException('Invalid question: ${json['id']}');
    }
    return Question(
      id: json['id'] as String,
      number: json['number'] as String,
      topic: json['topic'] as String,
      subject: subject,
      text: LocalizedText.fromJson(json['q']),
      answers: [for (final a in answers) LocalizedText.fromJson(a)],
      correctIndex: correct,
    );
  }
}

/// The answers of a question in the order they are shown.
class ShuffledAnswers {
  const ShuffledAnswers({required this.order, required this.correctPosition});

  /// `order[i]` is the canonical index of the answer shown at position `i`.
  final List<int> order;

  /// Position (in the shown order) of the correct answer.
  final int correctPosition;

  int get length => order.length;

  /// Canonical index of the answer shown at [position].
  int canonicalIndexAt(int position) => order[position];
}

/// Shuffles the answers of [question] for display. The bank itself is never
/// mutated; the result tells where the correct answer ended up.
ShuffledAnswers shuffledAnswers(Question question, Random random) {
  final order = List<int>.generate(question.answers.length, (i) => i)
    ..shuffle(random);
  return ShuffledAnswers(
    order: List.unmodifiable(order),
    correctPosition: order.indexOf(question.correctIndex),
  );
}
