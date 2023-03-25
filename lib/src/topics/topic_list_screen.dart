import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:pilotiq/src/exams/exam_builder.dart';
import 'package:pilotiq/src/home/home.dart';
import 'package:pilotiq/src/models.dart';

class TopicListScreen extends StatelessWidget {
  const TopicListScreen({super.key, required this.exam});

  final Exam exam;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    Widget body;
    switch (exam.type) {
      case ExamType.ppla:
        body = const ExamBuilder();
        break;
      case ExamType.pplaEng:
        body = const ExamBuilder(
          isEnglish: true,
        );
        break;
      case ExamType.pplh:
        body = const ExamBuilder(
          isHelicopter: true,
        );
        break;
      case ExamType.pplhEng:
        body = const ExamBuilder(
          isHelicopter: true,
          isEnglish: true,
        );
        break;
      case ExamType.plg:
        body = const ExamBuilder(
          isGlider: true,
        );
        break;
      case ExamType.plfb:
        body = const ExamBuilder(
          isBalloon: true,
        );
        break;
      default:
        return const Center(
          child: Text('No exam selected'),
        );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(local.topicsTitle),
        centerTitle: true,
        // actions: const [
        //   LanguageButton(),
        // ],
      ),
      body: body,
      // bottomNavigationBar: const BottomNavBar(),
    );
  }
}
