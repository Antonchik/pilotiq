import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/dashboard/dashboard_providers.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';

/// Bottom navigation: Today, Subjects, Profile.
class AppBottomNav extends ConsumerWidget {
  const AppBottomNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = AppLocalizations.of(context)!;
    return NavigationBar(
      selectedIndex: ref.watch(homeTabProvider),
      onDestinationSelected: (index) =>
          ref.read(homeTabProvider.notifier).state = index,
      destinations: [
        NavigationDestination(
          key: const Key('tab_today'),
          icon: const Icon(Icons.today_outlined),
          selectedIcon: const Icon(Icons.today),
          label: local.navToday,
        ),
        NavigationDestination(
          key: const Key('tab_subjects'),
          icon: const Icon(Icons.school_outlined),
          selectedIcon: const Icon(Icons.school),
          label: local.navSubjects,
        ),
        NavigationDestination(
          key: const Key('tab_profile'),
          icon: const Icon(Icons.person_outline),
          selectedIcon: const Icon(Icons.person),
          label: local.navProfile,
        ),
      ],
    );
  }
}
