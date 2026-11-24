import 'package:flutter/material.dart';
import 'package:pilotiq/src/exam_sim/exam_controller.dart';
import 'package:pilotiq/src/exam_sim/exam_history_screen.dart';
import 'package:pilotiq/src/exam_sim/exam_screen.dart';

/// Opens the exam simulation of a subject (rules, exam, result). Completes
/// when the user comes back.
Future<void> openExamSimulation(BuildContext context, ExamArgs args) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => ExamScreen(args: args)),
    );

/// Opens the list of finished attempts of a subject.
Future<void> openExamHistory(BuildContext context, ExamArgs args) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => ExamHistoryScreen(args: args)),
    );
