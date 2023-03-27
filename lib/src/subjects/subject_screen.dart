import 'package:flutter/material.dart';
import 'package:pilotiq/src/models.dart';
import 'package:pilotiq/src/quiz/quiz_list.dart';

class SubjectScreen extends StatelessWidget {
  final Subject subject;

  const SubjectScreen({super.key, required this.subject});

  @override
  Widget build(BuildContext context) {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final imageBlock = Container(
      color: Theme.of(context).colorScheme.surface,
      child: Hero(
        tag: subject.id,
        child: Image.asset(
          'assets/covers/${subject.img}',
          height: isPortrait ? 150 : null,
          width: MediaQuery.of(context).size.width * (isPortrait ? 1 : 0.25),
        ),
      ),
    );
    return Scaffold(
        appBar: AppBar(
          title: Text(subject.title),
          centerTitle: true,
        ),
        body: isPortrait
            ? ListView(children: [
                imageBlock,
                QuizList(subject: subject),
              ])
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  imageBlock,
                  Expanded(child: QuizList(subject: subject)),
                ],
              ));
  }
}
