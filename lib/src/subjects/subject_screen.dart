import 'package:flutter/material.dart';
import 'package:pilotiq/src/models.dart';
import 'package:pilotiq/src/quiz/quiz_list.dart';

class SubjectScreen extends StatelessWidget {
  final Subject subject;

  const SubjectScreen({super.key, required this.subject});

  @override
  Widget build(BuildContext context) {
    final isPortrait = MediaQuery.of(context).orientation.name == 'portrait';
    return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: Text(subject.title),
          centerTitle: true,
        ),
        body: isPortrait
            ? ListView(children: [
                Hero(
                  tag: subject.id,
                  child: Image.asset(
                    'assets/covers/${subject.img}',
                    height: 150,
                    width: MediaQuery.of(context).size.width,
                  ),
                ),
                QuizList(subject: subject),
              ])
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Hero(
                    tag: subject.id,
                    child: Image.asset(
                      'assets/covers/${subject.img}',
                      height: MediaQuery.of(context).size.height,
                      width: MediaQuery.of(context).size.width * 0.3,
                    ),
                  ),
                  Expanded(child: QuizList(subject: subject)),
                ],
              ));
  }
}
