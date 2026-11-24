import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/materials/materials_disclaimer.dart';
import 'package:pilotiq/src/materials/materials_providers.dart';
import 'package:pilotiq/src/materials/materials_screen.dart';
import 'package:pilotiq/src/materials/report_error.dart';
import 'package:pilotiq/src/purchases/paywall_launcher.dart';
import 'package:pilotiq/src/quiz/practice/practice_controller.dart';
import 'package:pilotiq/src/quiz/practice/practice_screen.dart';
import 'package:pilotiq/src/quiz/practice/practice_session.dart';
import 'package:pilotiq/src/subjects/subject_info.dart';

/// The summary of one topic: its sections with the sources, "report an
/// error" and the questions of the section. Locked sections show a teaser
/// with the button that opens the paywall.
class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({
    super.key,
    required this.subject,
    required this.topicId,
  });

  final SubjectInfo subject;
  final String topicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    final async = ref.watch(summariesProvider((subject.licence, subject.id)));
    final view = async.value;
    final topic = view?.topic(topicId);
    final languageCode = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          topic?.topic.title(languageCode) ?? local.materialsTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: async.isLoading && view == null
          ? const Center(child: CircularProgressIndicator())
          : view == null || topic == null
          ? const MaterialsEmpty()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                MaterialsDisclaimer(
                  legalStateAsOf: view.legalStateAsOf,
                  compact: true,
                ),
                const SizedBox(height: 8),
                for (final s in topic.sections)
                  _SectionCard(
                    key: ValueKey('summary_section_${s.section.id}'),
                    section: s,
                    view: view,
                    subject: subject,
                  ),
              ],
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    super.key,
    required this.section,
    required this.view,
    required this.subject,
  });

  final SectionView section;
  final SummariesView view;
  final SubjectInfo subject;

  void _openQuestions(BuildContext context, List<String> ids) {
    final args = PracticeArgs(
      licence: subject.licence,
      subject: subject.id,
      mode: PracticeMode.learn,
      questions: subject.questions,
    ).retry(ids, title: section.section.heading);
    openPractice(context, args);
  }

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final s = section.section;
    final known = {for (final q in subject.questions) q.id};
    final ids = [
      for (final id in section.questionIds)
        if (known.contains(id)) id,
    ];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Row(
                children: [
                  if (section.locked) ...[
                    const Icon(Icons.lock_outline, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(s.heading, style: theme.textTheme.titleMedium),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (section.locked) ...[
              Text(
                local.summaryLockedTitle,
                key: Key('summary_locked_${s.id}'),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                key: Key('summary_unlock_${s.id}'),
                onPressed: () => openPaywall(
                  context,
                  trigger: PaywallTrigger.materials,
                  explicit: true,
                ),
                child: Text(local.materialsUnlock),
              ),
            ] else ...[
              for (final paragraph in s.body) _Paragraph(text: paragraph),
              if (section.refs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    local.materialsSources(section.refs.join('; ')),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: Key('summary_report_${s.id}'),
                  icon: const Icon(Icons.flag_outlined, size: 18),
                  label: Text(local.materialsReportError),
                  onPressed: () => reportMaterialError(
                    context,
                    MaterialReport(
                      materialKey: s.id,
                      licence: view.licence,
                      materialsVersion: view.materialsVersion,
                    ),
                  ),
                ),
              ),
            ],
            if (ids.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: OutlinedButton(
                  key: Key('summary_questions_${s.id}'),
                  onPressed: () => _openQuestions(context, ids),
                  child: Text(local.summaryTopicQuestions(ids.length)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A paragraph of a section; `- text` is an item of a list.
class _Paragraph extends StatelessWidget {
  const _Paragraph({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    final item = text.startsWith('- ');
    if (!item) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: style),
      );
    }
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 8, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: style),
          Expanded(child: Text(text.substring(2), style: style)),
        ],
      ),
    );
  }
}
