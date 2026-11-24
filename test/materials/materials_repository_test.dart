import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilotiq/src/app.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/materials/explanation_panel.dart';
import 'package:pilotiq/src/materials/materials_models.dart';
import 'package:pilotiq/src/materials/materials_providers.dart';
import 'package:pilotiq/src/materials/materials_repository.dart';
import 'package:pilotiq/src/quiz/practice/practice_screen.dart';

import '../dashboard/dashboard_helpers.dart';
import 'materials_helpers.dart';

void main() {
  group('model', () {
    late SubjectMaterials m;
    setUp(() => m = parseMaterials(fixtureJson(), subject: SubjectId.airLaw));

    test('reads the fixture', () {
      expect(m.subject, SubjectId.airLaw);
      expect(m.materialsVersion, 'fx123456');
      expect(m.legalStateAsOf, DateTime(2026, 10, 1));
      expect(m.topics.map((t) => t.id), ['AL01', 'AL02']);
      expect(m.topics.first.sections.map((s) => s.id), ['AL01-1', 'AL01-2']);
      expect(m.topics.first.title('en'), 'Licences and ratings');
      expect(m.topics.first.title('pl'), 'Licencje i uprawnienia');
      expect(m.explanations, hasLength(7));
      expect(m.explanations[k6]!.status, MaterialStatus.disputed);
      expect(m.explanations[k6]!.disputeNote, isNotNull);
      expect(m.keyOf(Licence.ppla, 'PL010-0001'), k1);
      expect(m.keyOf(Licence.pplh, 'PL010-0001'), k6);
      expect(m.keyOf(Licence.ppla, 'PL010-0002'), isNull);
      expect(
        m.refLabel(m.explanations[k1]!.refs.single),
        'Prawo lotnicze, art. 128 ust. 1',
      );
      expect(m.isEmpty, isFalse);
    });

    test('the position in a topic counts only the keys of the licence', () {
      expect(
        [
          for (final k in [k1, k2, k3, k4, k5, k8])
            m.indexInTopic(Licence.ppla, k),
        ],
        [0, 1, 2, 3, 4, null],
      );
      // SPL has no K1 and K2: K3 is the first one there.
      expect(
        [
          for (final k in [k1, k2, k3, k4, k5, k8])
            m.indexInTopic(Licence.spl, k),
        ],
        [null, null, 0, 1, 2, 3],
      );
      expect(m.indexInTopic(Licence.pplh, k6), 0);
      expect(m.indexInTopic(Licence.bpl, k3), isNull);
    });

    test('question ids of a key', () {
      expect(m.questionIdsOf(Licence.ppla, k3), ['PL010-0003']);
      expect(m.questionIdsOf(Licence.bpl, k3), isEmpty);
    });

    test('records other than verified and disputed are not shown', () {
      final json = fixtureJson().replaceFirst(
        '"status": "verified"',
        '"status": "draft"',
      );
      expect(parseMaterials(json).explanations, hasLength(6));
    });

    test('another subject or schema is rejected', () {
      expect(
        () => parseMaterials(fixtureJson(), subject: SubjectId.meteorology),
        throwsFormatException,
      );
      expect(
        () => parseMaterials('{"schema": 2, "subject": "air_law"}'),
        throwsFormatException,
      );
    });

    test('the real asset of the app parses without errors', () {
      final file = File(materialsAssetPath(SubjectId.airLaw));
      expect(file.existsSync(), isTrue);
      final real = parseMaterials(
        file.readAsStringSync(),
        subject: SubjectId.airLaw,
      );
      expect(real.subject, SubjectId.airLaw);
      expect(real.materialsVersion, isNotEmpty);
      // Every link points to a shown explanation or a key of a summary.
      final sectionKeys = {
        for (final t in real.topics)
          for (final s in t.sections) ...s.questionKeys,
      };
      for (final links in real.links.values) {
        for (final key in links.values) {
          expect(
            real.explanations.containsKey(key) || sectionKeys.contains(key),
            isTrue,
            reason: key,
          );
        }
      }
    });
  });

  group('repository', () {
    test('reads the asset once and caches it', () async {
      final bundle = MaterialsBundle();
      final repo = materialsRepository(bundle);
      final a = repo.load(SubjectId.airLaw);
      final b = repo.load(SubjectId.airLaw);
      expect(await a, isNotNull);
      expect(identical(await a, await b), isTrue);
      await repo.load(SubjectId.airLaw);
      expect(bundle.materialReads, 1);
    });

    test('a subject without materials reads nothing', () async {
      final bundle = MaterialsBundle();
      final repo = materialsRepository(bundle);
      expect(await repo.load(SubjectId.meteorology), isNull);
      expect(bundle.reads, isEmpty);
    });

    test('a missing asset means no materials and is logged', () async {
      final logs = <String>[];
      final repo = materialsRepository(MaterialsBundle.missing(), logs: logs);
      expect(await repo.load(SubjectId.airLaw), isNull);
      expect(logs.single, contains('air_law.json'));
    });

    test('a broken asset means no materials and is logged', () async {
      final logs = <String>[];
      final repo = materialsRepository(
        MaterialsBundle('{"schema": 1, "subject"'),
        logs: logs,
      );
      expect(await repo.load(SubjectId.airLaw), isNull);
      expect(logs, hasLength(1));
    });

    test('small assets are parsed in place, big ones in the background', () {
      expect(materialsBackgroundParseBytes, greaterThan(1000));
    });
  });

  group('start-up', () {
    AppHarness.registerSetUp();

    testWidgets('the app starts without reading the materials; the first '
        'explanation reads them once and they are not read again', (
      tester,
    ) async {
      final h = AppHarness();
      final m = MaterialsHarness();
      await h.seedConfig();
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...h.overrides,
            materialsRepositoryProvider.overrideWithValue(m.repository),
            randomProviderOverride(),
          ],
          child: const MyApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(m.bundle.materialReads, 0);

      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      Future<void> openPractice() async {
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => PracticeScreen(args: learnArgs(Licence.ppla)),
          ),
        );
        await tester.pumpAndSettle();
      }

      await openPractice();
      expect(m.bundle.materialReads, 0, reason: 'nothing answered yet');
      await answerCurrent(tester);
      expect(find.byType(ExplanationPanel), findsOneWidget);
      expect(m.bundle.materialReads, 1);

      // PL010-0002 has no explanation, PL010-0003 has one.
      await nextQuestion(tester);
      await answerCurrent(tester);
      await nextQuestion(tester);
      await answerCurrent(tester);
      expect(find.byType(ExplanationPanel), findsOneWidget);

      navigator.pop();
      await tester.pumpAndSettle();
      await openPractice();
      await answerCurrent(tester);
      expect(m.bundle.materialReads, 1);
    });
  });
}
