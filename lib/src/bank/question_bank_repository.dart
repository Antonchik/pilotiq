import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/bank/bank_source.dart';
import 'package:pilotiq/src/bank/models.dart';
import 'package:pilotiq/src/domain/catalog.dart';

/// The parsed question bank of one licence.
class QuestionBank {
  QuestionBank._(
    this.licence,
    this.source,
    this.questions,
    this._bySubject,
    this._byId,
  );

  factory QuestionBank.fromQuestions(
    Licence licence,
    BankSourceInfo source,
    List<Question> questions,
  ) {
    final bySubject = <SubjectId, List<Question>>{};
    final byId = <String, Question>{};
    for (final q in questions) {
      if (byId.containsKey(q.id)) {
        throw FormatException('Duplicate question id ${q.id} in ${licence.id}');
      }
      byId[q.id] = q;
      bySubject.putIfAbsent(q.subject, () => []).add(q);
    }
    return QuestionBank._(
      licence,
      source,
      List.unmodifiable(questions),
      {for (final e in bySubject.entries) e.key: List.unmodifiable(e.value)},
      Map.unmodifiable(byId),
    );
  }

  final Licence licence;
  final BankSourceInfo source;
  final List<Question> questions;
  final Map<SubjectId, List<Question>> _bySubject;
  final Map<String, Question> _byId;

  /// Subjects that have at least one question, in catalogue order.
  List<SubjectId> get subjects => [
    for (final s in SubjectId.values)
      if (_bySubject[s]?.isNotEmpty ?? false) s,
  ];

  /// Questions of [subject]; empty if the bank has none.
  List<Question> questionsOf(SubjectId subject) =>
      _bySubject[subject] ?? const [];

  Question? questionById(String id) => _byId[id];
}

/// Parses the JSON text of `assets/data/bank_<licence>.json` (schema 2).
/// Top-level so that it can run in a background isolate.
QuestionBank parseBank(String jsonText, {required Licence licence}) {
  final data = jsonDecode(jsonText);
  if (data is! Map<String, dynamic> || data['schema'] != 2) {
    throw const FormatException('Unsupported question bank schema');
  }
  if (data['licence'] != licence.id) {
    throw FormatException(
      'Bank licence ${data['licence']} does not match ${licence.id}',
    );
  }
  final source = data['source'];
  final questions = data['questions'];
  if (source is! Map || questions is! List) {
    throw const FormatException('Malformed question bank');
  }
  return QuestionBank.fromQuestions(
    licence,
    BankSourceInfo(
      licence: licence,
      name: bankSourceName,
      databaseDate: bankDatabaseDate,
      file: '${source['file']}',
      fileDate: '${source['date']}',
      kind: '${source['kind']}',
    ),
    [for (final q in questions) Question.fromJson(q as Map<String, dynamic>)],
  );
}

class _ParseRequest {
  const _ParseRequest(this.json, this.licence);

  final String json;
  final Licence licence;
}

QuestionBank _parseRequest(_ParseRequest r) =>
    parseBank(r.json, licence: r.licence);

/// Parses a bank off the UI thread.
Future<QuestionBank> parseBankInBackground(String json, Licence licence) =>
    compute(_parseRequest, _ParseRequest(json, licence));

typedef BankParser = Future<QuestionBank> Function(
  String json,
  Licence licence,
);

/// Loads the banks from assets and keeps each of them in memory once loaded.
class QuestionBankRepository {
  QuestionBankRepository({AssetBundle? bundle, BankParser? parser})
    : _bundle = bundle ?? rootBundle,
      _parser = parser ?? parseBankInBackground;

  final AssetBundle _bundle;
  final BankParser _parser;
  final Map<Licence, Future<QuestionBank>> _cache = {};

  /// The bank of [licence]; the first call loads it, later calls (also while
  /// loading) share the same result. A failed load is not cached.
  Future<QuestionBank> load(Licence licence) {
    final cached = _cache[licence];
    if (cached != null) return cached;
    final future = _read(licence);
    _cache[licence] = future;
    unawaited(
      future.then<void>(
        (_) {},
        onError: (Object _) {
          if (identical(_cache[licence], future)) _cache.remove(licence);
        },
      ),
    );
    return future;
  }

  Future<QuestionBank> _read(Licence licence) async {
    final json = await _bundle.loadString(
      'assets/data/${licence.bankFileName}',
    );
    return _parser(json, licence);
  }
}

final questionBankRepositoryProvider = Provider<QuestionBankRepository>(
  (ref) => QuestionBankRepository(),
);

/// The bank of a licence, loaded once and cached by the repository.
final bankProvider = FutureProvider.family<QuestionBank, Licence>(
  (ref, licence) => ref.watch(questionBankRepositoryProvider).load(licence),
);

/// Source and database date of a licence's bank, for the UI ("About" etc.).
final bankSourceInfoProvider = FutureProvider.family<BankSourceInfo, Licence>(
  (ref, licence) async =>
      (await ref.watch(bankProvider(licence).future)).source,
);
