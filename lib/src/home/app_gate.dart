import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/home/home.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/onboarding/onboarding_screen.dart';
import 'package:pilotiq/src/progress/providers.dart';

/// Chooses the first screen: onboarding until it is done, then the home
/// screen. If the settings cannot be read, shows a retry screen instead of
/// leaving the app in a half-initialised state.
class AppGate extends ConsumerWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(userSettingsProvider);
    return settings.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => _SettingsErrorScreen(
        // A box that failed to open is remembered by the repository: retry
        // with a new one.
        onRetry: () => ref.invalidate(progressRepositoryProvider),
      ),
      data: (s) =>
          s.onboardingDone ? const HomeScreen() : const OnboardingScreen(),
    );
  }
}

class _SettingsErrorScreen extends StatelessWidget {
  const _SettingsErrorScreen({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(local.settingsStartupError, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('startup_retry'),
                onPressed: onRetry,
                child: Text(local.settingsRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
