import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilotiq/src/bank/question_bank_repository.dart';
import 'package:pilotiq/src/domain/catalog.dart';

/// Checks the real banks in `assets/data/`. Only invariants are asserted (no
/// concrete ids or question counts), because the converter may refresh them.
void main() {
  final numberFormat = RegExp(r'^PL\d{3}-\d{4}$');

  for (final licence in Licence.values) {
    group('bank ${licence.id}', () {
      final file = File('assets/data/${licence.bankFileName}');
      late String text;
      late Map<String, dynamic> raw;
      late List<Map<String, dynamic>> questions;

      setUpAll(() {
        text = file.readAsStringSync();
        raw = jsonDecode(text) as Map<String, dynamic>;
        questions = [
          for (final q in raw['questions'] as List) q as Map<String, dynamic>,
        ];
      });

      test('has schema 2, its licence and a source', () {
        expect(raw['schema'], 2);
        expect(raw['licence'], licence.id);
        expect(raw['source'], isA<Map>());
        expect((raw['source'] as Map)['kind'], 'pdf');
        expect(questions, isNotEmpty);
      });

      test('ids are unique', () {
        final ids = questions.map((q) => q['id'] as String).toList();
        expect(ids.toSet().length, ids.length);
      });

      test('numbers are normalised: no spaces, format PLxxx-yyyy', () {
        for (final q in questions) {
          final number = q['number'] as String;
          expect(number, matches(numberFormat), reason: '${q['id']}');
          expect(number.contains(RegExp(r'\s')), isFalse);
          expect(q['id'] as String, startsWith(number));
          expect((q['id'] as String).contains(RegExp(r'\s')), isFalse);
          expect(q['topic'], number.split('-').first);
        }
      });

      test('every question has text and 4 non-empty answers', () {
        for (final q in questions) {
          final id = q['id'];
          expect((q['q']['pl'] as String).trim(), isNotEmpty, reason: '$id');
          final answers = q['a'] as List;
          expect(answers, hasLength(4), reason: '$id');
          for (final a in answers) {
            expect((a['pl'] as String).trim(), isNotEmpty, reason: '$id');
          }
          expect(q['correct'], inInclusiveRange(0, 3), reason: '$id');
        }
      });

      test('topic maps to the subject of the catalogue', () {
        for (final q in questions) {
          expect(
            topicPrefixToSubject[q['topic']]?.id,
            q['subject'],
            reason: '${q['id']}',
          );
        }
      });

      test('every present subject has at least one exam of questions', () {
        final bank = parseBank(text, licence: licence);
        expect(bank.subjects, isNotEmpty);
        for (final subject in bank.subjects) {
          final spec = ExamSpec.forSubject(subject, licence: licence);
          expect(
            bank.questionsOf(subject).length,
            greaterThanOrEqualTo(spec.quizLength),
            reason: subject.id,
          );
          final numbers = {for (final q in bank.questionsOf(subject)) q.number};
          expect(
            numbers.length,
            greaterThanOrEqualTo(spec.quizLength),
            reason: '${subject.id}: distinct NUMERs',
          );
        }
      });

      test('the production parser accepts the file', () {
        final bank = parseBank(text, licence: licence);
        expect(bank.questions.length, questions.length);
        expect(bank.source.formattedDate, '01.08.2024');
      });
    });
  }

  test('PPL(H) contains the helicopter subject PL021', () {
    final raw = jsonDecode(
      File('assets/data/bank_pplh.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final topics = {for (final q in raw['questions'] as List) q['topic']};
    expect(topics, contains('PL021'));
  });

  test('assets/data holds only the bank files', () {
    final names = Directory('assets/data')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .toSet();
    expect(names, {for (final l in Licence.values) l.bankFileName});
  });
}
