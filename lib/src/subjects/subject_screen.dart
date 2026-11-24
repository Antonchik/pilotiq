import 'package:flutter/material.dart';
import 'package:pilotiq/src/about/about.dart';
import 'package:pilotiq/src/dark_theme/theme_mode_button.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/materials/materials_repository.dart';
import 'package:pilotiq/src/materials/materials_screen.dart';
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
                _MaterialsTile(subject: subject),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                imageBlock,
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        QuizList(subject: subject),
                        _MaterialsTile(subject: subject),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// "Study notes" of a subject that ships materials ([materialsSubjects]);
/// nothing for the other subjects. The materials are not loaded here.
class _MaterialsTile extends StatelessWidget {
  const _MaterialsTile({required this.subject});

  final SubjectInfo subject;

  @override
  Widget build(BuildContext context) {
    if (!materialsSubjects.contains(subject.id)) return const SizedBox.shrink();
    final local = AppLocalizations.of(context)!;
    return Card(
      key: const Key('mode_materials'),
      margin: const EdgeInsets.all(4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: const Icon(Icons.menu_book_outlined),
        title: Text(local.materialsTileTitle),
        subtitle: Text(local.materialsTileDescription),
        onTap: () => openMaterials(context, subject),
      ),
    );
  }
}
