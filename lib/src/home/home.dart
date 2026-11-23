import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/bank/licence_provider.dart';
import 'package:pilotiq/src/dashboard/dashboard_providers.dart';
import 'package:pilotiq/src/dashboard/dashboard_screen.dart';
import 'package:pilotiq/src/home/bottom_nav.dart';
import 'package:pilotiq/src/settings/settings_screen.dart';
import 'package:pilotiq/src/subjects/subject_list_screen.dart';

/// Main screen after the onboarding: the three tabs behind a bottom bar. Only
/// the visible tab is built, so "Today" recomputes whenever it is shown.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(homeTabProvider);
    final licence = ref.watch(selectedLicenceProvider);
    return PopScope(
      canPop: tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(homeTabProvider.notifier).state = 0;
      },
      child: Scaffold(
        body: switch (tab) {
          0 => const DashboardScreen(),
          1 => SubjectListScreen(key: ValueKey(licence), licence: licence),
          _ => const SettingsScreen(),
        },
        bottomNavigationBar: const AppBottomNav(),
      ),
    );
  }
}
