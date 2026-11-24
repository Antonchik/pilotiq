import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pilotiq/src/app.dart';
import 'package:pilotiq/src/dashboard/dashboard_providers.dart';
import 'package:pilotiq/src/dark_theme/theme_mode_provider.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/progress/legacy_migration.dart';
import 'package:pilotiq/src/progress/providers.dart';

import '../bank/memory_hive.dart';

/// Start-up with the real version 1.2.0 boxes of `test/fixtures/legacy_hive`.
void main() {
  late Directory dir;

  Future<void> copyFixtures(Iterable<String> names) async {
    for (final name in names) {
      await File('test/fixtures/legacy_hive/$name.hive')
          .copy('${dir.path}/$name.hive');
    }
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('pilotiq_startup_');
    Hive.init(dir.path);
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('the dark theme of 1.2.0 survives the start of 2.0', () async {
    await copyFixtures(['config', 'ppla', 'pplh', 'plg']);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await runStartupMigration(container), MigrationOutcome.migrated);

    final settings = await container.read(userSettingsProvider.future);
    expect(settings.onboardingDone, isFalse);
    expect(container.read(themeModeProvider), ThemeMode.dark);

    // Saving other settings afterwards must not bring the theme back.
    await container
        .read(userSettingsProvider.notifier)
        .change((s) => s.copyWith(dailyGoal: 40));
    expect(container.read(themeModeProvider), ThemeMode.dark);
    final reread = await container
        .read(progressRepositoryProvider)
        .loadSettings();
    expect(reread.themeMode.name, 'dark');
    expect(reread.dailyGoal, 40);
  });

  test('migrated results pre-select the licence of the onboarding', () async {
    await copyFixtures(['config', 'pplh']);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await runStartupMigration(container);

    expect(
      await container.read(legacyLicenceHintProvider.future),
      Licence.pplh,
    );
  });

  test('settings read before the migration are dropped after it', () async {
    await copyFixtures(['config', 'ppla']);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // Something read the settings too early.
    await container.read(userSettingsProvider.future);

    await runStartupMigration(container);

    expect(
      (await container.read(userSettingsProvider.future)).themeMode.name,
      'dark',
    );
  });

  test('a failed migration does not stop the start; old boxes stay', () async {
    await copyFixtures(['config', 'ppla', 'pplh']);
    // Damage a legacy box: the migration opens it without crash recovery.
    final broken = File('${dir.path}/pplh.hive');
    await broken.writeAsBytes(List<int>.filled(64, 0xFF));
    final before = {
      for (final f in dir.listSync().whereType<File>())
        f.path: f.readAsBytesSync(),
    };
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await runStartupMigration(container), MigrationOutcome.failed);

    final settings = await container.read(userSettingsProvider.future);
    expect(settings.schemaVersion, 0);
    expect(settings.licence, Licence.ppla);
    expect(container.read(themeModeProvider), ThemeMode.system);
    for (final name in ['config', 'ppla', 'pplh']) {
      final path = '${dir.path}/$name.hive';
      expect(File(path).readAsBytesSync(), before[path], reason: name);
    }
  });

  test('after a failure the next start migrates', () async {
    await copyFixtures(['config', 'ppla', 'pplh']);
    final broken = File('${dir.path}/pplh.hive');
    final good = broken.readAsBytesSync();
    await broken.writeAsBytes(List<int>.filled(64, 0xFF));
    var container = ProviderContainer();
    expect(await runStartupMigration(container), MigrationOutcome.failed);
    container.dispose();
    await Hive.close();

    await broken.writeAsBytes(good);
    container = ProviderContainer();
    addTearDown(container.dispose);
    expect(await runStartupMigration(container), MigrationOutcome.migrated);
    await container.read(userSettingsProvider.future);
    expect(container.read(themeModeProvider), ThemeMode.dark);
  });

  testWidgets('a failing initialisation shows a retry screen', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      PilotiqRoot(
        initialize: () async {
          calls++;
          if (calls == 1) throw StateError('disk is full');
          // Boxes in memory: file boxes cannot open inside fake-async.
          return ProviderContainer(
            overrides: [
              progressRepositoryProvider.overrideWithValue(
                memoryProgressRepository(),
              ),
            ],
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('startup_retry')), findsOneWidget);

    await tester.tap(find.byKey(const Key('startup_retry')));
    await tester.pump();
    await tester.pump();
    expect(calls, 2);
    expect(find.byKey(const Key('startup_retry')), findsNothing);
  });
}
