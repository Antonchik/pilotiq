import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/bank/licence_provider.dart';
import 'package:pilotiq/src/dashboard/dashboard_providers.dart';
import 'package:pilotiq/src/dashboard/dashboard_screen.dart';
import 'package:pilotiq/src/exam_sim/exam_sweep.dart';
import 'package:pilotiq/src/home/bottom_nav.dart';
import 'package:pilotiq/src/settings/settings_screen.dart';
import 'package:pilotiq/src/subjects/subject_list_screen.dart';

/// Main screen after the onboarding: the three tabs behind a bottom bar. Only
/// the visible tab is built, so "Today" recomputes whenever it is shown.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Exams whose time ran out while the app was closed are stored now.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) runExamSweep(ref);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the background: the day may have changed, answers may have
    // been given elsewhere.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(dashboardProvider);
      runExamSweep(ref);
    }
  }

  @override
  Widget build(BuildContext context) {
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
