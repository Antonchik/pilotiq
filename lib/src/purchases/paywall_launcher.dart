import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// Why the paywall is being opened.
enum PaywallTrigger {
  dailyLimit,
  examLimit,
  examResults,
  lockedFeature,
  profile,
}

/// Function that actually shows the paywall; overridden in tests.
typedef PaywallOpener = Future<void> Function(
  BuildContext context,
  PaywallTrigger trigger,
);

const _termsUrl = 'https://antonchik.github.io/pilotiq_tos/';
const _privacyUrl =
    'https://www.termsfeed.com/live/da031152-c5f9-4dd0-a4e6-42d78de414ae';

final paywallOpenerProvider = Provider<PaywallOpener>(
  (ref) =>
      (context, trigger) => Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => PaywallStubScreen(trigger: trigger)),
      ),
);

/// The single entry point for showing the paywall.
Future<void> openPaywall(
  BuildContext context, {
  required PaywallTrigger trigger,
}) {
  final container = ProviderScope.containerOf(context, listen: false);
  return container.read(paywallOpenerProvider)(context, trigger);
}

/// Temporary paywall screen, replaced by the real one in the paywall step.
class PaywallStubScreen extends StatelessWidget {
  const PaywallStubScreen({super.key, required this.trigger});

  final PaywallTrigger trigger;

  Future<void> _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(local.premiumTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              local.goPremiumLabel,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.new_releases_outlined),
              title: Text(local.allExamsAccessLabel),
            ),
            ListTile(
              leading: const Icon(Icons.subject),
              title: Text(local.allSubjectsAccessLabel),
            ),
            const SizedBox(height: 16),
            Text(local.paywallStubMessage, textAlign: TextAlign.center),
            const Spacer(),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => _open(_termsUrl),
                  child: Text(local.termsOfServiceLabel),
                ),
                TextButton(
                  onPressed: () => _open(_privacyUrl),
                  child: Text(local.privacyPolicyLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
