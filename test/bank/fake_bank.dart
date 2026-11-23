import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:flutter/services.dart';
import 'package:pilotiq/src/bank/question_bank_repository.dart';
import 'package:pilotiq/src/domain/catalog.dart';

Map<String, Object?> _text(String pl, String? en) => {'pl': pl, 'en': en};

Map<String, Object?> _question(
  String id,
  String subject,
  String qPl,
  String? qEn,
  List<(String, String?)> answers,
) => {
  'id': id,
  'number': id.split('~').first,
  'topic': id.substring(0, 5),
  'subject': subject,
  'q': _text(qPl, qEn),
  'a': [for (final a in answers) _text(a.$1, a.$2)],
  'correct': 0,
};

/// A tiny bank in the schema of `assets/data/bank_*.json`.
///
/// * PL010-0001: fully translated;
/// * PL010-0002: the question and 3 answers translated, answer 3 is not;
/// * PL010-0003: Polish only;
/// * PL010-0004: `<sub>` / `<sup>` tags and the "/n" tail;
/// * PL050-0001: a second subject.
String fakeBankJson(Licence licence) => jsonEncode({
  'schema': 2,
  'licence': licence.id,
  'source': {
    'file': 'fake.pdf',
    'sha256': '00',
    'date': '2024-07-26',
    'kind': 'pdf',
  },
  'questions': [
    _question(
      'PL010-0001',
      'air_law',
      'Wysokość nad ziemią to',
      'Height above ground is',
      [('AGL', 'AGL'), ('AMSL', 'AMSL'), ('FL', 'FL'), ('QNH', 'QNH')],
    ),
    _question(
      'PL010-0002',
      'air_law',
      'Pytanie z brakiem',
      'Missing question',
      [
        ('Odpowiedź pierwsza', 'First answer'),
        ('Odpowiedź druga', 'Second answer'),
        ('Odpowiedź trzecia', 'Third answer'),
        ('Odpowiedź czwarta', null),
      ],
    ),
    _question('PL010-0003', 'air_law', 'Tylko po polsku', null, [
      ('A', null),
      ('B', null),
      ('C', null),
      ('D', null),
    ]),
    _question(
      'PL010-0004',
      'air_law',
      'Wzór H<sub>2</sub>O i 10<sup>3</sup>',
      'Formula H<sub>2</sub>O and 10<sup>3</sup> /n',
      [
        ('jeden', 'one /n'),
        ('dwa', 'two'),
        ('trzy', 'three'),
        ('cztery', 'four'),
      ],
    ),
    _question(
      'PL050-0001',
      'meteorology',
      'Pytanie meteo',
      'Weather question',
      [('M1', 'M1'), ('M2', 'M2'), ('M3', 'M3'), ('M4', 'M4')],
    ),
  ],
});

/// Asset bundle that serves [fakeBankJson] and counts reads per file name.
class FakeBankBundle extends AssetBundle {
  final Map<String, int> reads = {};

  /// Keys whose first [failures] reads throw (to test a failed load).
  final Map<String, int> failures = {};

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    reads[key] = (reads[key] ?? 0) + 1;
    if ((failures[key] ?? 0) > 0) {
      failures[key] = failures[key]! - 1;
      throw FlutterError('cannot read $key');
    }
    final licence = Licence.values.firstWhere(
      (l) => key.endsWith(l.bankFileName),
    );
    return fakeBankJson(licence);
  }

  @override
  Future<ByteData> load(String key) async {
    final bytes = Uint8List.fromList(utf8.encode(await loadString(key)));
    return ByteData.sublistView(bytes);
  }
}

/// A repository over [bundle] that parses on the calling isolate, so widget
/// tests do not depend on real isolates.
QuestionBankRepository fakeBankRepository([FakeBankBundle? bundle]) =>
    QuestionBankRepository(
      bundle: bundle ?? FakeBankBundle(),
      parser: (json, licence) async => parseBank(json, licence: licence),
    );
