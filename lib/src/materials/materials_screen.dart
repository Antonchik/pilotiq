import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/materials/materials_disclaimer.dart';
import 'package:pilotiq/src/materials/materials_providers.dart';
import 'package:pilotiq/src/materials/summary_screen.dart';
import 'package:pilotiq/src/subjects/subject_info.dart';

/// Opens the study notes of [subject].
Future<void> openMaterials(BuildContext context, SubjectInfo subject) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MaterialsScreen(subject: subject),
      ),
    );

/// Topics of the study notes of a subject, with the disclaimer and the date
/// of the legal state. Opening it is what loads the materials.
class MaterialsScreen extends ConsumerWidget {
  const MaterialsScreen({super.key, required this.subject});

  final SubjectInfo subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    final async = ref.watch(summariesProvider((subject.licence, subject.id)));
    return Scaffold(
      appBar: AppBar(title: Text(local.materialsTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const MaterialsEmpty(),
        data: (view) {
          if (view == null) return const MaterialsEmpty();
          final languageCode = Localizations.localeOf(context).languageCode;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              MaterialsDisclaimer(
                legalStateAsOf: view.legalStateAsOf,
                polishOnlyNote: languageCode != 'pl',
              ),
              const SizedBox(height: 12),
              for (final t in view.topics)
                Card(
                  key: ValueKey('materials_topic_${t.topic.id}'),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text(t.topic.title(languageCode)),
                    subtitle: Text(
                      local.materialsSectionCount(t.sections.length),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => SummaryScreen(
                          subject: subject,
                          topicId: t.topic.id,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// "No materials for this subject".
class MaterialsEmpty extends StatelessWidget {
  const MaterialsEmpty({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.menu_book_outlined, size: 48),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.materialsEmpty,
            key: const Key('materials_empty'),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
