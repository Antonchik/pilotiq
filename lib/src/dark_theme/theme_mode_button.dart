import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/progress/providers.dart';
import 'package:pilotiq/src/progress/user_settings.dart';
import 'package:pilotiq/src/settings/settings_tiles.dart';

/// Switches between the light and the dark theme. When the theme follows the
/// system, the button switches to the opposite of what is shown now.
class ThemeModeButton extends ConsumerWidget {
  const ThemeModeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode_outlined),
      onPressed: ref.watch(userSettingsProvider).hasValue
          ? () => changeSettings(
              context,
              ref,
              (s) => s.copyWith(
                themeMode: isDark ? AppThemeMode.light : AppThemeMode.dark,
              ),
              themeChosen: true,
            )
          : null,
    );
  }
}
