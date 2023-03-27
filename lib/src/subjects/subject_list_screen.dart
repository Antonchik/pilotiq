import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pilotiq/src/home/home.dart';
import 'package:pilotiq/src/models.dart';
import 'package:pilotiq/src/subjects/subject_list_builder.dart';

class SubjectListScreen extends StatelessWidget {
  const SubjectListScreen({super.key, required this.exam});

  final Exam exam;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    Widget body;
    switch (exam.type) {
      case ExamType.ppla:
        body = const SubjectListBuilder();
        break;
      case ExamType.pplaEng:
        body = const SubjectListBuilder(
          isEnglish: true,
        );
        break;
      case ExamType.pplh:
        body = const SubjectListBuilder(
          isHelicopter: true,
        );
        break;
      case ExamType.pplhEng:
        body = const SubjectListBuilder(
          isHelicopter: true,
          isEnglish: true,
        );
        break;
      case ExamType.plg:
        body = const SubjectListBuilder(
          isGlider: true,
        );
        break;
      case ExamType.plfb:
        body = const SubjectListBuilder(
          isBalloon: true,
        );
        break;
      default:
        return const Center(
          child: Text('No exam selected'),
        );
    }
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final children = [
      SizedBox(
        height: isPortrait ? 150 : double.infinity,
        width: isPortrait ? double.infinity : 150,
        child: Hero(
          tag: exam.img,
          child: Image.asset(
            'assets/covers/${exam.img}',
            fit: BoxFit.scaleDown,
          ),
        ),
      ),
      Expanded(child: body),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(local.subjectsTitle),
      ),
      body: isPortrait
          ? Column(
              children: children,
            )
          : Row(
              children: children,
            ),
      // bottomNavigationBar: const BottomNavBar(),
    );
  }
}
