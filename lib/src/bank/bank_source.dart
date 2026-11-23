import 'package:pilotiq/src/domain/catalog.dart';

/// Official name of the source of the questions, for the UI.
const String bankSourceName = 'ULC, Przykładowe pytania egzaminacyjne';

/// Date of the question database shown to the user: the "Aktualizacja" date of
/// the ULC page (01.08.2024, confirmed by the owner). The PDF files themselves
/// were created on 2024-07-26 (`source.date` in the banks), so that value is
/// deliberately not used for display.
final DateTime bankDatabaseDate = DateTime(2024, 8, 1);

/// `dd.MM.yyyy`.
String formatBankDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.'
    '${date.month.toString().padLeft(2, '0')}.${date.year}';

/// Where the questions of one licence come from.
class BankSourceInfo {
  const BankSourceInfo({
    required this.licence,
    required this.name,
    required this.databaseDate,
    required this.file,
    required this.fileDate,
    required this.kind,
  });

  final Licence licence;

  /// [bankSourceName].
  final String name;

  /// Date of the database shown to the user ([bankDatabaseDate]).
  final DateTime databaseDate;

  /// Source file recorded in the bank (`source.file`).
  final String file;

  /// Creation date of that file as recorded in the bank (`source.date`).
  final String fileDate;
  final String kind;

  String get formattedDate => formatBankDate(databaseDate);
}
