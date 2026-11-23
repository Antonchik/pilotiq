import 'package:flutter/material.dart';
import 'package:pilotiq/src/about/about.dart';
import 'package:pilotiq/src/dark_theme/theme_mode_button.dart';
import 'package:pilotiq/src/quiz/quiz_list.dart';
import 'package:pilotiq/src/subjects/subject_info.dart';

class SubjectScreen extends StatelessWidget {
  final SubjectInfo subject;

  const SubjectScreen({super.key, required this.subject});

  @override
  Widget build(BuildContext context) {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final imageBlock = Container(
      color: Theme.of(context).colorScheme.surface,
      child: Hero(
        tag: '${subject.licence.id}_${subject.id.id}',
        child: Image.asset(
          'assets/covers/${subject.image}',
          height: isPortrait ? 150 : null,
          width: MediaQuery.of(context).size.width * (isPortrait ? 1 : 0.25),
          excludeFromSemantics: true,
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(subject.title),
        actions: const [ThemeModeButton(), ApplicationVersionWidget()],
      ),
      body: isPortrait
          ? ListView(
              children: [
                imageBlock,
                QuizList(subject: subject),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                imageBlock,
                Expanded(
                  child: SingleChildScrollView(
                    child: QuizList(subject: subject),
                  ),
                ),
              ],
            ),
    );
  }
}
