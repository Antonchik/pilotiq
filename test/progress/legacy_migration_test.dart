import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/progress/exam_attempt.dart';
import 'package:pilotiq/src/progress/legacy_migration.dart';
import 'package:pilotiq/src/progress/progress_repository.dart';
import 'package:pilotiq/src/progress/user_settings.dart';

void main() {
  late Directory dir;
  late ProgressRepository repo;
  late LegacyMigration migration;

  Map<String, List<int>> snapshotFiles() => {
    for (final f in dir.listSync().whereType<File>())
      if (f.path.endsWith('.hive'))
        f.uri.pathSegments.last: f.readAsBytesSync(),
  };

  Future<Map<String, Map<dynamic, dynamic>>> legacyContents() async {
    final out = <String, Map<dynamic, dynamic>>{};
    for (final name in ['config', 'ppla', 'pplh', 'plg']) {
      final box = await Hive.openBox<dynamic>(name);
      out[name] = Map.of(box.toMap());
      await box.close();
    }
    return out;
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('legacy_migration_');
    for (final f in Directory(
      'test/fixtures/legacy_hive',
    ).listSync().whereType<File>()) {
      if (f.path.endsWith('.hive')) {
        await f.copy('${dir.path}/${f.uri.pathSegments.last}');
      }
    }
    Hive.init(dir.path);
    repo = ProgressRepository();
    migration = LegacyMigration(repository: repo);
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('real fixtures: dark theme, legacy attempts, schemaVersion 2', () async {
    expect(await migration.run(), MigrationOutcome.migrated);

    final settings = await repo.loadSettings();
    expect(settings.themeMode, AppThemeMode.dark);
    expect(settings.schemaVersion, 2);

    final airLaw = await repo.attempts(Licence.ppla, subject: SubjectId.airLaw);
    expect(airLaw, hasLength(3));
    expect(airLaw.every((a) => a.reason == AttemptReason.legacy), isTrue);
    expect(airLaw.where((a) => a.passed), hasLength(2));
    expect(airLaw.where((a) => !a.passed), hasLength(1));

    final meteo = await repo.attempts(
      Licence.pplh,
      subject: SubjectId.meteorology,
    );
    expect(meteo, hasLength(1));
    expect(meteo.single.passed, isFalse);

    // the empty-string position key of `plg` yields nothing
    expect(await repo.attempts(Licence.spl), isEmpty);
    expect(await repo.attempts(Licence.bpl), isEmpty);
  });

  test('second run is a no-op and duplicates nothing', () async {
    await migration.run();
    final count =
        (await repo.attempts(Licence.ppla)).length +
        (await repo.attempts(Licence.pplh)).length;
    expect(await migration.run(), MigrationOutcome.alreadyDone);
    expect(
      (await repo.attempts(Licence.ppla)).length +
          (await repo.attempts(Licence.pplh)).length,
      count,
    );
    expect(count, 4);
  });

  test(
    're-running after a lost schemaVersion still does not duplicate',
    () async {
      await migration.run();
      final cfg = await Hive.openBox<dynamic>('config');
      await cfg.put('schemaVersion', 0);
      expect(await migration.run(), MigrationOutcome.migrated);
      expect(
        await repo.attempts(Licence.ppla, subject: SubjectId.airLaw),
        hasLength(3),
      );
    },
  );

  test('old boxes are not changed or deleted', () async {
    // opening config for settings writes new keys there, so check the
    // legacy-specific content: values and keys that existed before
    final before = await legacyContents();
    final filesBefore = snapshotFiles();
    await migration.run();
    await Hive.close();
    Hive.init(dir.path);

    for (final name in ['ppla', 'pplh', 'plg']) {
      expect(
        filesBefore[name == 'ppla' ? 'ppla.hive' : '$name.hive'],
        isNotNull,
      );
      final box = await Hive.openBox<dynamic>(name);
      expect(box.toMap(), before[name], reason: name);
      await box.close();
    }
    final after = snapshotFiles();
    for (final name in ['ppla.hive', 'pplh.hive', 'plg.hive']) {
      expect(after[name], filesBefore[name], reason: '$name bytes unchanged');
    }
    // the legacy `dark` key stays in config
    final config = await Hive.openBox<dynamic>('config');
    expect(config.get('dark'), true);
  });

  test('pplaEng box merges into PPL(A) with distinct ids', () async {
    final eng = await Hive.openBox<dynamic>('pplaEng');
    await eng.put('air_law_positive', 1);
    await eng.put('air_law_negative', 2);
    await eng.close();
    await migration.run();
    final airLaw = await repo.attempts(Licence.ppla, subject: SubjectId.airLaw);
    expect(airLaw, hasLength(6));
    expect(airLaw.map((a) => a.id).toSet(), hasLength(6));
  });

  test(
    'missing legacy boxes: no empty boxes are created, defaults kept',
    () async {
      for (final f in dir.listSync().whereType<File>()) {
        if (!f.path.endsWith('config.hive')) f.deleteSync();
      }
      final cfg = await Hive.openBox<dynamic>('config');
      await cfg.delete('dark');
      await cfg.close();
      expect(await migration.run(), MigrationOutcome.migrated);
      final settings = await repo.loadSettings();
      expect(settings.themeMode, AppThemeMode.system);
      expect(settings.schemaVersion, 2);
      expect(File('${dir.path}/ppla.hive').existsSync(), isFalse);
      expect(File('${dir.path}/pplaeng.hive').existsSync(), isFalse);
    },
  );

  test('light legacy theme maps to light', () async {
    final cfg = await Hive.openBox<dynamic>('config');
    await cfg.put('dark', false);
    await cfg.close();
    await migration.run();
    expect((await repo.loadSettings()).themeMode, AppThemeMode.light);
  });

  test('a failure does not throw and does not raise schemaVersion', () async {
    final failing = LegacyMigration(
      repository: repo,
      boxExists: (_) async => true,
      openBox: (name) async {
        if (name == 'ppla') throw StateError('boom');
        return Hive.openBox<dynamic>(name);
      },
    );
    expect(await failing.run(), MigrationOutcome.failed);
    expect((await repo.loadSettings()).schemaVersion, 0);
    // a later healthy run completes the migration
    expect(await migration.run(), MigrationOutcome.migrated);
    expect((await repo.loadSettings()).schemaVersion, 2);
  });

  test(
    'a legacy file with a garbage tail makes the run fail and stays intact',
    () async {
      final file = File('${dir.path}/ppla.hive');
      final damaged = [...file.readAsBytesSync(), 1, 2, 3, 4, 5, 6, 7];
      file.writeAsBytesSync(damaged);
      expect(await migration.run(), MigrationOutcome.failed);
      expect(file.readAsBytesSync(), damaged);
      expect((await repo.loadSettings()).schemaVersion, 0);
    },
  );

  test('a stale settings object cannot roll schemaVersion back', () async {
    // object read before the migration (wrong order in the caller)
    final stale = await repo.loadSettings();
    await migration.run();
    await repo.saveSettings(stale.copyWith(dailyGoal: 40));
    final now = await repo.loadSettings();
    expect(now.schemaVersion, 2);
    expect(now.dailyGoal, 40);
    expect(await migration.run(), MigrationOutcome.alreadyDone);
  });
}
