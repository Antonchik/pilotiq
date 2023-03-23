import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pilotiq/src/exams/exam_item.dart';
import 'package:pilotiq/src/models.dart';
import 'package:pilotiq/src/settings/language_button.dart';

enum ExamType { ppla, pplaEng, pplh, pplhEng, plg, plfb }

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final exams = [
      Exam(
        type: ExamType.ppla,
        title: local.pplaExamTitle,
        // description: local.airLawTopicTooltip,
        img: 'ppla.png',
      ),
      Exam(
        type: ExamType.pplaEng,
        title: local.pplaEngExamTitle,
        // description: local.airLawTopicTooltip,
        img: 'ppla-en.png',
      ),
      Exam(
        type: ExamType.pplh,
        title: local.pplhExamTitle,
        // description: local.airLawTopicTooltip,
        img: 'pplh.png',
      ),
      Exam(
        type: ExamType.pplh,
        title: local.pplhEngExamTitle,
        // description: local.airLawTopicTooltip,
        img: 'pplh-en.png',
      ),
      Exam(
        type: ExamType.plg,
        title: local.plgExamTitle,
        // description: local.airLawTopicTooltip,
        img: 'plg.png',
      ),
      Exam(
        type: ExamType.plfb,
        title: local.plfbExamTitle,
        // description: local.airLawTopicTooltip,
        img: 'plfb.png',
      )
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(local.examsTitle),
        actions: const [
          LanguageButton(),
        ],
      ),
      // backgroundColor: Theme.of(context).canvasColor,
      body: GridView.count(
        primary: false,
        padding: const EdgeInsets.all(20.0),
        crossAxisSpacing: 10.0,
        crossAxisCount: 2,
        children: exams.map((exam) => ExamItem(exam: exam)).toList(),
      ),
    );
  }
}
