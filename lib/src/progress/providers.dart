import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/progress/legacy_migration.dart';
import 'package:pilotiq/src/progress/progress_repository.dart';
import 'package:pilotiq/src/progress/user_settings.dart';

/// Source of "now"; override in tests with a fake clock.
final clockProvider = Provider<Clock>((ref) => const Clock());

/// Source of randomness; override with a seeded [Random] in tests.
final randomProvider = Provider<Random>((ref) => Random());

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => ProgressRepository(),
);

final legacyMigrationProvider = Provider<LegacyMigration>(
  (ref) => LegacyMigration(repository: ref.watch(progressRepositoryProvider)),
);

class UserSettingsNotifier extends AsyncNotifier<UserSettings> {
  @override
  Future<UserSettings> build() =>
      ref.watch(progressRepositoryProvider).loadSettings();

  /// Applies [mutate] to the current settings and persists the result.
  /// [themeChosen]: the change is the user's own theme choice.
  Future<void> change(
    UserSettings Function(UserSettings current) mutate, {
    bool themeChosen = false,
  }) async {
    final current = state.value ?? await future;
    final next = mutate(current);
    await ref
        .read(progressRepositoryProvider)
        .saveSettings(next, themeChosen: themeChosen);
    state = AsyncData(next);
  }
}

final userSettingsProvider =
    AsyncNotifierProvider<UserSettingsNotifier, UserSettings>(
      UserSettingsNotifier.new,
    );
