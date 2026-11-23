import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/purchases/paywall_launcher.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';
import 'package:pilotiq/src/settings/settings_tiles.dart';

/// "Profile" tab: premium, learning settings, appearance, reminders slot and
/// the About screen.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    final isPremium = ref.watch(isPremiumProvider);
    return Scaffold(
      appBar: AppBar(title: Text(local.settingsTitle)),
      body: ListView(
        children: [
          Card(
            child: ListTile(
              key: const Key('settings_premium'),
              leading: Icon(
                isPremium ? Icons.verified : Icons.star,
                color: Theme.of(context).primaryColor,
              ),
              title: Text(local.premiumTitle),
              subtitle: Text(
                isPremium
                    ? local.settingsPremiumActive
                    : local.settingsPremiumGet,
              ),
              trailing: isPremium ? null : const Icon(Icons.chevron_right),
              onTap: isPremium
                  ? null
                  : () => openPaywall(context, trigger: PaywallTrigger.profile),
            ),
          ),
          const PurchasesSettingsSlot(),
          SettingsSectionHeader(local.settingsSectionLearning),
          const LicenceTile(),
          const QuestionLanguageTile(),
          const ExamDateTile(),
          const DailyGoalTile(),
          SettingsSectionHeader(local.settingsSectionAppearance),
          const ThemeTile(),
          const RemindersSettingsSlot(),
          const Divider(),
          ListTile(
            key: const Key('settings_about'),
            leading: const Icon(Icons.info_outline),
            title: Text(local.aboutTitle),
            subtitle: Text(local.settingsAboutSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed('/about'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
