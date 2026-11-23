import 'dart:developer' as developer;

import 'package:hive_ce/hive.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/progress/exam_attempt.dart';
import 'package:pilotiq/src/progress/progress_repository.dart';
import 'package:pilotiq/src/progress/user_settings.dart';

enum MigrationOutcome { migrated, alreadyDone, failed }

/// Moves pre-2.0 data into the new storage. Idempotent (guarded by
/// `config.schemaVersion`, attempts have deterministic ids) and never touches
/// the old boxes: they are opened only to read.
///
/// - `config.dark` becomes `themeMode`.
/// - `<subject>_positive` / `<subject>_negative` counters of the legacy boxes
///   become that many passed / failed attempts with `reason: legacy`.
/// - The "continue from question N" position is dropped on purpose.
class LegacyMigration {
  LegacyMigration({
    required this._repository,
    BoxOpener? openBox,
    Future<bool> Function(String name)? boxExists,
  }) : _openBox = openBox ?? ((name) => Hive.openBox<dynamic>(name)),
       _boxExists = boxExists ?? ((name) => Hive.boxExists(name));

  final ProgressRepository _repository;
  final BoxOpener _openBox;
  final Future<bool> Function(String name) _boxExists;

  static final DateTime legacyTimestamp = DateTime.utc(1970);

  Future<MigrationOutcome> run() async {
    try {
      final settings = await _repository.loadSettings();
      if (settings.schemaVersion >= UserSettings.currentSchemaVersion) {
        return MigrationOutcome.alreadyDone;
      }

      final config = await _openBox(ProgressRepository.configBox);
      var themeMode = settings.themeMode;
      final dark = config.get('dark');
      if (dark is bool) {
        themeMode = dark ? AppThemeMode.dark : AppThemeMode.light;
      }

      for (final entry in legacyBoxToLicence.entries) {
        if (!await _boxExists(entry.key)) continue;
        final box = await _openBox(entry.key);
        try {
          for (final subject in SubjectId.values) {
            final positive = _count(box.get('${subject.id}_positive'));
            final negative = _count(box.get('${subject.id}_negative'));
            for (var i = 0; i < positive; i++) {
              await _repository.saveAttempt(
                _attempt(
                  entry.key,
                  entry.value,
                  subject,
                  passed: true,
                  index: i,
                ),
              );
            }
            for (var i = 0; i < negative; i++) {
              await _repository.saveAttempt(
                _attempt(
                  entry.key,
                  entry.value,
                  subject,
                  passed: false,
                  index: i,
                ),
              );
            }
          }
        } finally {
          await box.close();
        }
      }

      await _repository.saveSettings(
        settings.copyWith(
          themeMode: themeMode,
          schemaVersion: UserSettings.currentSchemaVersion,
        ),
      );
      return MigrationOutcome.migrated;
    } on Object catch (e, st) {
      developer.log(
        'Legacy data migration failed',
        name: 'pilotiq.migration',
        error: e,
        stackTrace: st,
      );
      return MigrationOutcome.failed;
    }
  }

  static int _count(Object? v) => v is num && v > 0 ? v.toInt() : 0;

  static ExamAttempt _attempt(
    String legacyBox,
    Licence licence,
    SubjectId subject, {
    required bool passed,
    required int index,
  }) => ExamAttempt(
    id: 'legacy_${legacyBox}_${subject.id}_${passed ? 'pass' : 'fail'}_$index',
    licence: licence,
    subject: subject,
    startedAt: legacyTimestamp,
    finishedAt: legacyTimestamp,
    durationSec: 0,
    total: 0,
    correct: 0,
    passed: passed,
    reason: AttemptReason.legacy,
  );
}
