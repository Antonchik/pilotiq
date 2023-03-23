import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/settings/language_provider.dart';

class LanguageButton extends ConsumerWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';
    final local = AppLocalizations.of(context)!;
    return IconButton(
      onPressed: () {
        if (isEnglish) {
          ref.read(languageProvider.notifier).state =
              const Locale.fromSubtags(languageCode: 'pl');
        } else {
          ref.read(languageProvider.notifier).state =
              const Locale.fromSubtags(languageCode: 'en');
        }
      },
      tooltip: local.languageButtonTooltip,
      // icon: const Icon(Icons.translate, size: 20),
      icon: Text(
        isEnglish ? 'EN' : 'PL',
        // style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}
