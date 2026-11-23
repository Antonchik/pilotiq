import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilotiq/src/bank/bank_source.dart';
import 'package:pilotiq/src/bank/models.dart';
import 'package:pilotiq/src/bank/question_bank_repository.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/progress/user_settings.dart';

import 'fake_bank.dart';

void main() {
  group('QuestionBankRepository', () {
    test('caches a bank per licence and does not reread the asset', () async {
      final bundle = FakeBankBundle();
      final repo = fakeBankRepository(bundle);

      final first = await repo.load(Licence.ppla);
      final second = await repo.load(Licence.ppla);
      final concurrent = await Future.wait([
        repo.load(Licence.ppla),
        repo.load(Licence.ppla),
      ]);

      expect(identical(first, second), isTrue);
      expect(concurrent.every((b) => identical(b, first)), isTrue);
      expect(bundle.reads['assets/data/bank_ppla.json'], 1);

      await repo.load(Licence.pplh);
      expect(bundle.reads['assets/data/bank_pplh.json'], 1);
      expect(bundle.reads['assets/data/bank_ppla.json'], 1);
    });

    test('a failed load is not cached and can be retried', () async {
      final bundle = FakeBankBundle()
        ..failures['assets/data/bank_spl.json'] = 1;
      final repo = fakeBankRepository(bundle);

      await expectLater(repo.load(Licence.spl), throwsA(isA<FlutterError>()));
      final bank = await repo.load(Licence.spl);

      expect(bank.licence, Licence.spl);
      expect(bundle.reads['assets/data/bank_spl.json'], 2);
    });

    test('groups questions by subject and finds them by id', () async {
      final bank = await fakeBankRepository().load(Licence.ppla);

      expect(bank.subjects, [SubjectId.airLaw, SubjectId.meteorology]);
      expect(bank.questionsOf(SubjectId.airLaw), hasLength(4));
      expect(bank.questionsOf(SubjectId.navigation), isEmpty);
      expect(bank.questionById('PL050-0001')!.subject, SubjectId.meteorology);
      expect(bank.questionById('nope'), isNull);
      expect(
        () => bank.questionsOf(SubjectId.airLaw).add(bank.questions.first),
        throwsUnsupportedError,
      );
    });

    test('exposes source name and the database date for the UI', () async {
      final bank = await fakeBankRepository().load(Licence.ppla);

      expect(bank.source.name, 'ULC, Przykładowe pytania egzaminacyjne');
      expect(bank.source.formattedDate, '01.08.2024');
      expect(bank.source.databaseDate, bankDatabaseDate);
      // The PDF creation date stays available, but is not the shown date.
      expect(bank.source.fileDate, '2024-07-26');
      expect(bank.source.file, 'fake.pdf');
    });

    test('parseBank rejects a bank of another licence or schema', () {
      final json = fakeBankJson(Licence.ppla);
      expect(
        () => parseBank(json, licence: Licence.pplh),
        throwsFormatException,
      );
      expect(
        () => parseBank(
          json.replaceFirst('"schema":2', '"schema":1'),
          licence: Licence.ppla,
        ),
        throwsFormatException,
      );
    });
  });

  group('shuffledAnswers', () {
    late Question question;

    setUp(() async {
      question = (await fakeBankRepository().load(Licence.ppla))
          .questionById('PL010-0001')!;
    });

    test('keeps track of the correct answer for every seed', () {
      for (var seed = 0; seed < 50; seed++) {
        final s = shuffledAnswers(question, Random(seed));
        expect(s.order.toSet(), {0, 1, 2, 3});
        expect(s.canonicalIndexAt(s.correctPosition), question.correctIndex);
      }
    });

    test(
      'is deterministic for a seed, varies between seeds, mutates nothing',
      () {
        final a = shuffledAnswers(question, Random(7));
        final b = shuffledAnswers(question, Random(7));
        expect(a.order, b.order);
        final orders = {
          for (var seed = 0; seed < 30; seed++)
            shuffledAnswers(question, Random(seed)).order.join(),
        };
        expect(orders.length, greaterThan(1));
        expect(question.answers.map((x) => x.pl), ['AGL', 'AMSL', 'FL', 'QNH']);
        expect(() => a.order.add(9), throwsUnsupportedError);
      },
    );
  });

  group('language', () {
    late QuestionBank bank;

    setUp(() async {
      bank = await fakeBankRepository().load(Licence.ppla);
    });

    test('LocalizedText falls back from English to Polish', () {
      const text = LocalizedText(pl: 'Tak', en: 'Yes');
      const missing = LocalizedText(pl: 'Tak');
      const blank = LocalizedText(pl: 'Tak', en: '  ');
      expect(text.resolve(QuestionLanguage.en), 'Yes');
      expect(text.resolve(QuestionLanguage.pl), 'Tak');
      expect(missing.resolve(QuestionLanguage.en), 'Tak');
      expect(blank.resolve(QuestionLanguage.en), 'Tak');
    });

    test('a fully translated question is shown in English', () {
      final q = bank.questionById('PL010-0001')!;
      expect(q.hasFullEnglish, isTrue);
      expect(q.displayLanguage(QuestionLanguage.en), QuestionLanguage.en);
      expect(q.displayLanguage(QuestionLanguage.pl), QuestionLanguage.pl);
    });

    test('one answer without English makes the whole question Polish', () {
      final q = bank.questionById('PL010-0002')!;
      expect(q.text.hasEnglish, isTrue);
      expect(q.hasFullEnglish, isFalse);
      expect(q.displayLanguage(QuestionLanguage.en), QuestionLanguage.pl);
    });

    test('a question without English is shown in Polish', () {
      final q = bank.questionById('PL010-0003')!;
      expect(q.displayLanguage(QuestionLanguage.en), QuestionLanguage.pl);
    });
  });
}
