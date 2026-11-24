import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/about/about.dart';
import 'package:pilotiq/src/about/legal_links.dart';
import 'package:pilotiq/src/bank/bank_source.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// What an error report about the study materials says.
class MaterialReport {
  const MaterialReport({
    required this.materialKey,
    required this.licence,
    required this.materialsVersion,
    this.questionId,
  });

  /// Content key of an explanation or id of a summary section.
  final String materialKey;
  final Licence licence;
  final String materialsVersion;

  /// The question the explanation was shown for.
  final String? questionId;
}

/// `[Pilotiq] Błąd w materiałach: <key|sectionId>`.
String materialReportSubject(MaterialReport r) =>
    '[Pilotiq] Błąd w materiałach: ${r.materialKey}';

/// Body of the report. It is read by the authors, so the labels are fixed
/// (Polish, like the materials) and do not follow the UI language.
String materialReportBody(
  MaterialReport r, {
  required String appVersion,
  required String bankDate,
}) => [
  'Materiał: ${r.materialKey}',
  if (r.questionId != null) 'Pytanie: ${r.questionId}',
  'Licencja: ${r.licence.id}',
  'Wersja aplikacji: $appVersion',
  'Wersja materiałów: ${r.materialsVersion}',
  'Data bazy pytań: $bankDate',
  '',
  'Opis błędu:',
  '',
].join('\n');

/// `mailto:` link of the report, or `null` when no address is configured.
Uri? materialReportMailto(String email, String subject, String body) {
  if (email.trim().isEmpty) return null;
  return Uri(
    scheme: 'mailto',
    path: email.trim(),
    query: [
      'subject=${Uri.encodeComponent(subject)}',
      'body=${Uri.encodeComponent(body)}',
    ].join('&'),
  );
}

/// Address of the reports; [materialsReportEmail] (empty until the owner
/// gives one). Tests replace it.
final materialsReportEmailProvider = Provider<String>(
  (ref) => materialsReportEmail,
);

/// Opens a `mailto:` link; `false` when no mail app took it. Tests replace it.
final materialsMailLauncherProvider = Provider<Future<bool> Function(Uri uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// Sends [report]: an e-mail when an address is configured and a mail app
/// opens, otherwise a dialog with the text and a "copy" button.
Future<void> reportMaterialError(
  BuildContext context,
  MaterialReport report,
) async {
  final container = ProviderScope.containerOf(context, listen: false);
  var appVersion = '?';
  try {
    final info = await container.read(packageInfoProvider.future);
    appVersion = '${info.version}+${info.buildNumber}';
  } on Object catch (_) {
    // The version is only informative.
  }
  final subject = materialReportSubject(report);
  final body = materialReportBody(
    report,
    appVersion: appVersion,
    bankDate: formatBankDate(bankDatabaseDate),
  );
  final uri = materialReportMailto(
    container.read(materialsReportEmailProvider),
    subject,
    body,
  );
  if (uri != null) {
    var opened = false;
    try {
      opened = await container.read(materialsMailLauncherProvider)(uri);
    } on Object catch (_) {
      opened = false;
    }
    if (opened) return;
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => MaterialReportDialog(text: '$subject\n\n$body'),
  );
}

/// The text of a report with a "copy" button. The confirmation of the copy
/// is shown inside the dialog (a snack bar would be hidden by its barrier).
class MaterialReportDialog extends StatefulWidget {
  const MaterialReportDialog({super.key, required this.text});

  final String text;

  @override
  State<MaterialReportDialog> createState() => _MaterialReportDialogState();
}

class _MaterialReportDialogState extends State<MaterialReportDialog> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return AlertDialog(
      key: const Key('materials_report_dialog'),
      title: Text(local.materialsReportDialogTitle),
      scrollable: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(local.materialsReportDialogBody),
          const SizedBox(height: 12),
          SelectableText(widget.text, key: const Key('materials_report_text')),
          if (_copied)
            Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        local.materialsReportCopied,
                        key: const Key('materials_report_copied'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('materials_report_copy'),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: widget.text));
            if (mounted) setState(() => _copied = true);
          },
          child: Text(local.materialsReportCopy),
        ),
        TextButton(
          key: const Key('materials_report_close'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(local.materialsReportClose),
        ),
      ],
    );
  }
}
