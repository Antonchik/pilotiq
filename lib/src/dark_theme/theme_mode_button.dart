import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pilotiq/src/dark_theme/theme_mode_provider.dart';
import 'package:pilotiq/src/purchases/linkfive_provider.dart';
import 'package:pilotiq/src/purchases/paywall.dart';

class ThemeModeButton extends ConsumerWidget {
  const ThemeModeButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(linkFiveProvider).hasActiveProduct;
    final isDark =
        isPremium ? ref.watch(themeModeProvider) == ThemeMode.dark : false;
    final settingsBox = Hive.box('config');
    return isPremium
        ? IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode_outlined),
            onPressed: () {
              ref
                  .read(themeModeProvider.notifier)
                  .update((mode) => isDark ? ThemeMode.light : ThemeMode.dark);
              settingsBox.put(ThemeMode.dark.name, !isDark);
            },
          )
        : const SizedBox.shrink();
  }
}
