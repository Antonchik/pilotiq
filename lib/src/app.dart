import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linkfive_purchases/logic/linkfive_purchases.dart';
import 'package:pilotiq/src/dark_theme/theme_mode_provider.dart';
import 'package:pilotiq/src/purchases/linkfive_provider.dart';
import 'package:pilotiq/src/routes.dart';
import 'package:pilotiq/src/theme.dart';

import 'settings/settings_controller.dart';

class MyApp extends ConsumerWidget {
  const MyApp({
    super.key,
    required this.settingsController,
  });

  final SettingsController settingsController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.read(linkFiveProvider);
    return AnimatedBuilder(
      animation: settingsController,
      builder: (BuildContext context, Widget? child) {
        final themeMode = ref.watch(themeModeProvider);
        return MaterialApp(
          restorationScopeId: 'app',
          debugShowCheckedModeBanner: false,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          onGenerateTitle: (BuildContext context) =>
              AppLocalizations.of(context)!.appTitle,
          theme: lightAppTheme,
          darkTheme: darkAppTheme,
          themeMode: themeMode,
          routes: appRoutes,
        );
      },
    );
  }
}
