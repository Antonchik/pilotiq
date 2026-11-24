import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pilotiq/src/about/legal_links.dart';
import 'package:pilotiq/src/bank/bank_source.dart';
import 'package:pilotiq/src/bank/licence_presentation.dart';
import 'package:pilotiq/src/bank/question_bank_repository.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/materials/materials_disclaimer.dart';
import 'package:pilotiq/src/materials/materials_providers.dart';
import 'package:url_launcher/url_launcher.dart';

/// Package info is read from the platform once and then cached.
final packageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

/// App bar button that opens the About screen.
class ApplicationVersionWidget extends StatelessWidget {
  const ApplicationVersionWidget({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    icon: const Icon(Icons.info_outline),
    tooltip: AppLocalizations.of(context)!.aboutTitle,
    onPressed: () => Navigator.of(context).pushNamed('/about'),
  );
}

/// Version, disclaimer, source and date of the question database.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  Future<void> _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final info = ref.watch(packageInfoProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(local.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Image.asset(
              'assets/icon/launcher_icon.png',
              height: 90,
              excludeFromSemantics: true,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            info?.appName ?? local.appTitle,
            style: textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          if (info != null)
            Text(
              local.aboutVersion(info.version, info.buildNumber),
              key: const Key('about_version'),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 16),
          Text(
            local.aboutDisclaimer,
            key: const Key('about_disclaimer'),
            style: textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          Semantics(
            header: true,
            child: Text(local.aboutBankTitle, style: textTheme.titleMedium),
          ),
          const SizedBox(height: 8),
          for (final licence in Licence.values)
            _BankSourceLine(licence: licence),
          const SizedBox(height: 8),
          Text(local.aboutQuestionsNote, style: textTheme.bodySmall),
          const SizedBox(height: 24),
          Semantics(
            header: true,
            child: Text(
              local.aboutMaterialsTitle,
              style: textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 8),
          const _MaterialsNote(),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => _open(termsOfServiceUrl),
                child: Text(local.termsOfServiceLabel),
              ),
              TextButton(
                onPressed: () => _open(privacyPolicyUrl),
                child: Text(local.privacyPolicyLabel),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(local.copyright, style: textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// "PPL(A): ULC, Przykładowe pytania egzaminacyjne, 01.08.2024". The source
/// and date come from the loaded bank; until it is loaded (or if it cannot be
/// loaded) the same published values are shown.
class _BankSourceLine extends ConsumerWidget {
  const _BankSourceLine({required this.licence});

  final Licence licence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    final source = ref.watch(bankSourceInfoProvider(licence)).value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        local.aboutBankSourceLine(
          licence.title(local),
          source?.name ?? bankSourceName,
          source?.formattedDate ?? formatBankDate(bankDatabaseDate),
        ),
        key: Key('about_source_${licence.id}'),
      ),
    );
  }
}

/// Disclaimer of the study materials with the date of their legal state.
/// The About screen is opened by the user, so reading the (small) materials
/// asset here does not happen at start-up.
class _MaterialsNote extends ConsumerWidget {
  const _MaterialsNote();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final materials = ref.watch(materialsProvider(SubjectId.airLaw)).value;
    return MaterialsDisclaimer(
      key: const Key('about_materials'),
      legalStateAsOf: materials?.legalStateAsOf,
      polishOnlyNote: true,
    );
  }
}
