import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:pilotiq/src/dark_theme/theme_mode_provider.dart';

class ThemeModeButton extends ConsumerWidget {
  const ThemeModeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    return IconButton(
      icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode_outlined),
      onPressed: () {
        final settingsBox = Hive.box('config');
        ref
            .read(themeModeProvider.notifier)
            .update((mode) => isDark ? ThemeMode.light : ThemeMode.dark);
        settingsBox.put(ThemeMode.dark.name, !isDark);
      },
    );
  }
}
