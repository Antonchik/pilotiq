import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/domain/dates.dart';

enum AppThemeMode { system, light, dark }

enum QuestionLanguage {
  pl,
  en;

  static QuestionLanguage fromId(Object? id) => QuestionLanguage.values
      .firstWhere((l) => l.name == id, orElse: () => QuestionLanguage.pl);
}

class ReminderTime {
  const ReminderTime(this.hour, this.minute);

  final int hour;
  final int minute;

  /// `HH:mm`
  String encode() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  static ReminderTime? tryParse(Object? v) {
    if (v is! String) return null;
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(v);
    if (m == null) return null;
    final h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    if (h > 23 || min > 59) return null;
    return ReminderTime(h, min);
  }

  @override
  bool operator ==(Object other) =>
      other is ReminderTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => encode();
}

/// User settings, stored as flat keys of the `config` box (next to the legacy
/// `dark` key, which is left untouched).
class UserSettings {
  const UserSettings({
    this.licence = Licence.ppla,
    this.questionLanguage = QuestionLanguage.pl,
    this.examDate,
    this.dailyGoal = defaultDailyGoal,
    this.reminderTime,
    this.themeMode = AppThemeMode.system,
    this.onboardingDone = false,
    this.schemaVersion = 0,
  });

  static const int defaultDailyGoal = 20;

  /// Current storage schema (legacy migration writes it).
  static const int currentSchemaVersion = 2;

  final Licence licence;
  final QuestionLanguage questionLanguage;

  /// Date only (local midnight).
  final DateTime? examDate;
  final int dailyGoal;
  final ReminderTime? reminderTime;
  final AppThemeMode themeMode;
  final bool onboardingDone;
  final int schemaVersion;

  UserSettings copyWith({
    Licence? licence,
    QuestionLanguage? questionLanguage,
    DateTime? examDate,
    bool clearExamDate = false,
    int? dailyGoal,
    ReminderTime? reminderTime,
    bool clearReminderTime = false,
    AppThemeMode? themeMode,
    bool? onboardingDone,
    int? schemaVersion,
  }) => UserSettings(
    licence: licence ?? this.licence,
    questionLanguage: questionLanguage ?? this.questionLanguage,
    examDate: clearExamDate ? null : (examDate ?? this.examDate),
    dailyGoal: dailyGoal ?? this.dailyGoal,
    reminderTime: clearReminderTime
        ? null
        : (reminderTime ?? this.reminderTime),
    themeMode: themeMode ?? this.themeMode,
    onboardingDone: onboardingDone ?? this.onboardingDone,
    schemaVersion: schemaVersion ?? this.schemaVersion,
  );

  /// All settings as a map. `ProgressRepository.saveSettings` does not write
  /// `schemaVersion` from it: only the legacy migration owns that key.
  Map<String, dynamic> toMap() => {
    'licence': licence.id,
    'questionLanguage': questionLanguage.name,
    'examDate': examDate == null ? null : dateKey(examDate!),
    'dailyGoal': dailyGoal,
    'reminderTime': reminderTime?.encode(),
    'themeMode': themeMode.name,
    'onboardingDone': onboardingDone,
    'schemaVersion': schemaVersion,
  };

  /// Tolerant reader: values of the wrong type fall back to the defaults.
  factory UserSettings.fromMap(Map<dynamic, dynamic> m) {
    final goal = m['dailyGoal'];
    final licence = m['licence'];
    final examDate = m['examDate'];
    final schema = m['schemaVersion'];
    return UserSettings(
      licence: (licence is String ? Licence.fromId(licence) : null) ??
          Licence.ppla,
      questionLanguage: QuestionLanguage.fromId(m['questionLanguage']),
      examDate: examDate is String ? parseDateKey(examDate) : null,
      dailyGoal: goal is num && goal.toInt() > 0
          ? goal.toInt()
          : defaultDailyGoal,
      reminderTime: ReminderTime.tryParse(m['reminderTime']),
      themeMode: AppThemeMode.values.firstWhere(
        (t) => t.name == m['themeMode'],
        orElse: () => AppThemeMode.system,
      ),
      onboardingDone: m['onboardingDone'] == true,
      schemaVersion: schema is num ? schema.toInt() : 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReminderTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => encode();
}

/// User settings, stored as flat keys of the `config` box (next to the legacy
/// `dark` key, which is left untouched).
class UserSettings {
  const UserSettings({
    this.licence = Licence.ppla,
    this.questionLanguage = QuestionLanguage.pl,
    this.examDate,
    this.dailyGoal = defaultDailyGoal,
    this.reminderTime,
    this.themeMode = AppThemeMode.system,
    this.onboardingDone = false,
    this.schemaVersion = 0,
  });

  static const int defaultDailyGoal = 20;

  /// Current storage schema (legacy migration writes it).
  static const int currentSchemaVersion = 2;

  final Licence licence;
  final QuestionLanguage questionLanguage;

  /// Date only (local midnight).
  final DateTime? examDate;
  final int dailyGoal;
  final ReminderTime? reminderTime;
  final AppThemeMode themeMode;
  final bool onboardingDone;
  final int schemaVersion;

  UserSettings copyWith({
    Licence? licence,
    QuestionLanguage? questionLanguage,
    DateTime? examDate,
    bool clearExamDate = false,
    int? dailyGoal,
    ReminderTime? reminderTime,
    bool clearReminderTime = false,
    AppThemeMode? themeMode,
    bool? onboardingDone,
    int? schemaVersion,
  }) => UserSettings(
    licence: licence ?? this.licence,
    questionLanguage: questionLanguage ?? this.questionLanguage,
    examDate: clearExamDate ? null : (examDate ?? this.examDate),
    dailyGoal: dailyGoal ?? this.dailyGoal,
    reminderTime: clearReminderTime
        ? null
        : (reminderTime ?? this.reminderTime),
    themeMode: themeMode ?? this.themeMode,
    onboardingDone: onboardingDone ?? this.onboardingDone,
    schemaVersion: schemaVersion ?? this.schemaVersion,
  );

  /// All settings as a map. `ProgressRepository.saveSettings` does not write
  /// `schemaVersion` from it: only the legacy migration owns that key.
  Map<String, dynamic> toMap() => {
    'licence': licence.id,
    'questionLanguage': questionLanguage.name,
    'examDate': examDate == null ? null : dateKey(examDate!),
    'dailyGoal': dailyGoal,
    'reminderTime': reminderTime?.encode(),
    'themeMode': themeMode.name,
    'onboardingDone': onboardingDone,
    'schemaVersion': schemaVersion,
  };

  factory UserSettings.fromMap(Map<dynamic, dynamic> m) {
    final goal = (m['dailyGoal'] as num?)?.toInt();
    return UserSettings(
      licence: Licence.fromId(m['licence'] as String?) ?? Licence.ppla,
      questionLanguage: QuestionLanguage.fromId(m['questionLanguage']),
      examDate: parseDateKey(m['examDate'] as String?),
      dailyGoal: goal != null && goal > 0 ? goal : defaultDailyGoal,
      reminderTime: ReminderTime.tryParse(m['reminderTime']),
      themeMode: AppThemeMode.values.firstWhere(
        (t) => t.name == m['themeMode'],
        orElse: () => AppThemeMode.system,
      ),
      onboardingDone: m['onboardingDone'] == true,
      schemaVersion: (m['schemaVersion'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is UserSettings &&
      other.licence == licence &&
      other.questionLanguage == questionLanguage &&
      other.examDate == examDate &&
      other.dailyGoal == dailyGoal &&
      other.reminderTime == reminderTime &&
      other.themeMode == themeMode &&
      other.onboardingDone == onboardingDone &&
      other.schemaVersion == schemaVersion;

  @override
  int get hashCode => Object.hash(
    licence,
    questionLanguage,
    examDate,
    dailyGoal,
    reminderTime,
    themeMode,
    onboardingDone,
    schemaVersion,
  );
}
