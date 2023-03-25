import 'package:json_annotation/json_annotation.dart';
import 'package:pilotiq/src/home/home.dart';

@JsonSerializable()
class Exam {
  final ExamType type;
  final String title;
  final String description;
  final String img;

  Exam({
    required this.type,
    this.title = '',
    this.description = '',
    this.img = 'default-cover.png',
  });
}

@JsonSerializable()
class Topic {
  late final String id;
  final String title;
  final String description;
  final String img;
  final int examTime;
  final int quizLength;
  final List<Question> questions;

  Topic({
    this.id = '',
    this.title = '',
    this.description = '',
    this.img = 'default-cover.png',
    this.examTime = 30,
    this.quizLength = 12,
    this.questions = const [],
  });
}

@JsonSerializable()
class Quiz {
  String id;
  String title;
  String description;
  String topic;
  int time;
  List<Question> questions;

  Quiz(
      {this.title = '',
      this.description = '',
      this.id = '',
      this.topic = '',
      this.time = 30,
      this.questions = const []});
}

@JsonSerializable()
class Question {
  String seq;
  String number;
  String question;
  List<Answer> answers;

  Question(
      {this.answers = const [],
      this.question = '',
      this.number = '',
      this.seq = ''});

  factory Question.fromJson(Map<String, dynamic> json) {
    List<Answer> answers = [];
    answers.add(Answer(value: json['ODP1'].toString(), isCorrect: true));
    answers.add(Answer(value: json['ODP2'].toString()));
    answers.add(Answer(value: json['ODP3'].toString()));
    answers.add(Answer(value: json['ODP4'].toString()));
    answers.shuffle();
    return Question(
      seq: json['L.p.'],
      number: json['NUMER'],
      question: json['PYTANIE'],
      answers: answers,
    );
  }
}

@JsonSerializable()
class Answer {
  String value;
  bool isCorrect;

  Answer({this.value = '', this.isCorrect = false});
}
