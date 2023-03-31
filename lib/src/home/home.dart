import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pilotiq/src/about/about.dart';
import 'package:pilotiq/src/dark_theme/theme_mode_button.dart';
import 'package:pilotiq/src/exams/exam_item.dart';
import 'package:pilotiq/src/models.dart';

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
        img: 'ppla.png',
      ),
      Exam(
        type: ExamType.pplaEng,
        title: local.pplaEngExamTitle,
        img: 'ppla-en.png',
      ),
      Exam(
        type: ExamType.pplh,
        title: local.pplhExamTitle,
        img: 'pplh.png',
      ),
      Exam(
        type: ExamType.pplh,
        title: local.pplhEngExamTitle,
        img: 'pplh-en.png',
      ),
      Exam(
        type: ExamType.plg,
        title: local.plgExamTitle,
        img: 'plg.png',
      ),
      Exam(
        type: ExamType.plfb,
        title: local.plfbExamTitle,
        img: 'plfb.png',
      )
    ];
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    return Scaffold(
      appBar: AppBar(
        title: Text(local.examsTitle),
        actions: const [
          ThemeModeButton(),
          ApplicationVersionWidget(),
          // IconButton(
          //     onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          //         builder: (context) => const PurchasePage())),
          //     icon: const Icon(Icons.store))
        ],
      ),
      body: isPortrait
          ? ListView.builder(
              shrinkWrap: true,
              itemCount: exams.length,
              itemBuilder: (context, index) =>
                  SizedBox(height: 90, child: ExamItem(exam: exams[index])),
            )
          : ListView.builder(
              shrinkWrap: true,
              itemCount: (exams.length * 0.5).ceil(),
              itemBuilder: (context, index) => Row(
                children: [
                  Flexible(
                    child: SizedBox(
                        height: 90, child: ExamItem(exam: exams[index * 2])),
                  ),
                  Flexible(
                    child: SizedBox(
                        height: 90,
                        child: index * 2 + 1 < exams.length
                            ? ExamItem(exam: exams[index * 2 + 1])
                            : const SizedBox.expand()),
                  ),
                ],
              ),
            ),
    );
  }
}
