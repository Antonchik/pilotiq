import 'package:flutter/material.dart';
import 'package:pilotiq/src/about/about.dart';
import 'package:pilotiq/src/dark_theme/theme_mode_button.dart';
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
          actions: const [
            ThemeModeButton(),
            ApplicationVersionWidget(),
          ],
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
