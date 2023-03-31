import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pilotiq/src/dark_theme/theme_mode_provider.dart';

class ThemeModeButton extends ConsumerWidget {
  const ThemeModeButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    return IconButton(
        onPressed: () {
          final settingsBox = Hive.box('config');
          ref
              .read(themeModeProvider.notifier)
              .update((mode) => isDark ? ThemeMode.light : ThemeMode.dark);
          settingsBox.put(ThemeMode.dark.name, !isDark);
        },
        icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode_outlined));
  }
}
