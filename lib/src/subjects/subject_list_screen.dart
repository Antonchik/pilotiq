import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/about/about.dart';
import 'package:pilotiq/src/bank/bank_source.dart';
import 'package:pilotiq/src/bank/licence_presentation.dart';
import 'package:pilotiq/src/dark_theme/theme_mode_button.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/exams/question_language_selector.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/subjects/subject_list_builder.dart';

class SubjectListScreen extends ConsumerWidget {
  const SubjectListScreen({super.key, required this.licence});

  final Licence licence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final cover = SizedBox(
      height: isPortrait ? 150 : double.infinity,
      width: isPortrait
          ? double.infinity
          : MediaQuery.of(context).size.width * 0.2,
      child: Hero(
        tag: licence.coverImage,
        child: Image.asset(
          'assets/covers/${licence.coverImage}',
          fit: BoxFit.scaleDown,
          excludeFromSemantics: true,
        ),
      ),
    );
    final content = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QuestionLanguageSelector(licence: licence),
          Expanded(child: SubjectListBuilder(licence: licence)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              local.bankSourceNote(
                bankSourceName,
                formatBankDate(bankDatabaseDate),
              ),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text('${licence.title(local)} · ${local.subjectsTitle}'),
        actions: const [ThemeModeButton(), ApplicationVersionWidget()],
      ),
      body: isPortrait
          ? Column(children: [cover, content])
          : Row(children: [cover, content]),
    );
  }
}
