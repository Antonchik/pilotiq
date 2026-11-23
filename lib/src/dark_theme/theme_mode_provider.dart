import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/progress/providers.dart';
import 'package:pilotiq/src/progress/user_settings.dart';

/// Theme mode of the app, derived from the stored settings (system by
/// default; the legacy `dark` flag is carried over by the migration).
final themeModeProvider = Provider<ThemeMode>(
  (ref) => switch (ref.watch(userSettingsProvider).value?.themeMode) {
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
    _ => ThemeMode.system,
  },
);
