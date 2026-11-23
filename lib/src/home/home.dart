import 'package:flutter/material.dart';
import 'package:pilotiq/src/about/about.dart';
import 'package:pilotiq/src/dark_theme/theme_mode_button.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/exams/licence_item.dart';
import 'package:pilotiq/src/exams/question_language_selector.dart';
import 'package:pilotiq/src/home/bottom_nav.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    const licences = Licence.values;
    return Scaffold(
      appBar: AppBar(
        title: Text(local.examsTitle),
        actions: const [ThemeModeButton(), ApplicationVersionWidget()],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const QuestionLanguageSelector(),
          Expanded(
            child: ListView.builder(
              itemCount: licences.length,
              itemBuilder: (context, index) =>
                  LicenceItem(licence: licences[index]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(),
    );
  }
}
