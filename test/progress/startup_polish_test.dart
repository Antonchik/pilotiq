import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/progress/legacy_migration.dart';
import 'package:pilotiq/src/progress/progress_repository.dart';
import 'package:pilotiq/src/progress/user_settings.dart';

import 'helpers.dart';

/// Polish package, section A: storage details of the progress layer.
void main() {
  late Directory dir;
  final now = DateTime(2026, 5, 1, 12);

  setUp(() async => dir = await initTempHive());
  tearDown(() => disposeTempHive(dir));

  test('A2: an interrupted answer is rolled back when the app starts', () async {
    final repo = ProgressRepository();
    await repo.recordAnswer(Licence.ppla, 'q', true, now);
    // Simulate a process killed between the writes of the next answer: the
    // progress is already changed, the daily stat is not, the journal remains.
    final progress = await Hive.openBox<dynamic>('progress_ppla');
    final daily = await Hive.openBox<dynamic>('daily');
    final config = await Hive.openBox<dynamic>('config');
    final key = '2026-05-01';
    await config.put('pending_answer', {
      'licence': 'ppla',
      'qid': 'q',
      'dailyKey': key,
      'prevProgress': Map<dynamic, dynamic>.of(progress.get('q') as Map),
      'prevDaily': Map<dynamic, dynamic>.of(daily.get(key) as Map),
    });
    await progress.put('q', {
      ...Map<String, dynamic>.from(progress.get('q') as Map),
      'seen': 2,
    });
    await Hive.close();
    Hive.init(dir.path);

    final fresh = ProgressRepository();
    await fresh.recoverPending();

    // Read without any write in between: the answer is not half counted.
    expect((await fresh.progressOf(Licence.ppla, 'q'))!.seen, 1);
    expect(
      (await Hive.openBox<dynamic>('config')).containsKey('pending_answer'),
      isFalse,
    );
  });

  group('A3: only a damaged file is recovered', () {
    setUp(() => ProgressRepository.clearRecoveryEvents());

    test('a file system error is a plain error, no copy, no event', () async {
      File('${dir.path}/config.hive').writeAsBytesSync([1, 2, 3]);
      var opens = 0;
      await expectLater(
        ProgressRepository.openWithBackupUsing('config', (
          name, {
          required crashRecovery,
        }) {
          opens++;
          throw const FileSystemException('locked');
        }),
        throwsA(isA<FileSystemException>()),
      );
      expect(opens, 1);
      expect(
        dir.listSync().map((f) => f.path).where((p) => p.contains('.bak-')),
        isEmpty,
      );
      expect(ProgressRepository.recoveryEvents, isEmpty);
    });

    test('a HiveError (damaged file) still recovers with a copy', () async {
      File('${dir.path}/config.hive').writeAsBytesSync([1, 2, 3]);
      final box = await Hive.openBox<dynamic>('config');
      await box.close();
      var first = true;
      await ProgressRepository.openWithBackupUsing('config', (
        name, {
        required crashRecovery,
      }) {
        if (first) {
          first = false;
          throw HiveError('Wrong checksum');
        }
        return Hive.openBox<dynamic>(name);
      });
      expect(ProgressRepository.recoveryEvents.single.reset, isFalse);
      expect(File('${dir.path}/config.hive.bak-1').existsSync(), isTrue);
    });
  });

  test(
    'A4: an explicit "System" theme is not overridden by the migration',
    () async {
      final repo = ProgressRepository();
      final base = await repo.loadSettings();
      await repo.saveSettings(
        base.copyWith(themeMode: AppThemeMode.system),
        themeChosen: true,
      );
      // The legacy 1.2.0 flag says dark; the chosen theme wins.
      await (await Hive.openBox<dynamic>('config')).put('dark', true);

      expect(
        await LegacyMigration(repository: repo).run(),
        MigrationOutcome.migrated,
      );
      expect((await repo.loadSettings()).themeMode, AppThemeMode.system);
    },
  );
}
