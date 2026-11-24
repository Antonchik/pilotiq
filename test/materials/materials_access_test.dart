import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilotiq/src/domain/access_policy.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/materials/materials_providers.dart';
import 'package:pilotiq/src/purchases/fake_purchase_service.dart';
import 'package:pilotiq/src/purchases/paywall_launcher.dart';
import 'package:pilotiq/src/purchases/paywall_screen.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';

import '../purchases/paywall_helpers.dart';
import 'materials_helpers.dart';

void main() {
  ProviderContainer container({bool premium = false}) {
    final c = ProviderContainer(
      overrides: [
        purchaseServiceProvider.overrideWithValue(
          FakePurchaseService(premium: premium),
        ),
        materialsRepositoryProvider.overrideWithValue(
          materialsRepository(MaterialsBundle()),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<Map<String, bool?>> lockedOf(
    ProviderContainer c,
    Licence licence,
    List<String> ids,
  ) async => {
    for (final id in ids)
      id: (await c.read(explanationForQuestionProvider((licence, id)).future))
          ?.locked,
  };

  test('free PPL(A): the first 3 explanations of the topic are open, the '
      '4th and later are locked', () async {
    final c = container();
    expect(
      await lockedOf(c, Licence.ppla, [
        'PL010-0001',
        'PL010-0010',
        'PL010-0003',
        'PL010-0004',
        'PL010-0005',
        'PL010-0002',
      ]),
      {
        'PL010-0001': false,
        'PL010-0010': false,
        'PL010-0003': false,
        'PL010-0004': true,
        'PL010-0005': true,
        // No explanation at all.
        'PL010-0002': null,
      },
    );
  });

  test('a locked view carries no Premium content, only the status', () async {
    final c = container();
    final v = (await c.read(
      explanationForQuestionProvider((Licence.ppla, 'PL010-0005')).future,
    ))!;
    expect(v.locked, isTrue);
    expect(v.disputed, isTrue);
    expect(v.text, isEmpty);
    expect(v.refs, isEmpty);
    expect(v.disputeNote, isNull);

    final premium = (await container(premium: true).read(
      explanationForQuestionProvider((Licence.ppla, 'PL010-0005')).future,
    ))!;
    expect(premium.locked, isFalse);
    expect(premium.text, isNotEmpty);
    expect(premium.disputeNote, isNotNull);
  });

  test('outdated: everyone gets the mark, only premium the note; it takes '
      'no place of the free sample', () async {
    final free = (await container().read(
      explanationForQuestionProvider((Licence.pplh, 'PL010-0002')).future,
    ))!;
    expect(free.outdated, isTrue);
    expect(free.hasExplanation, isFalse);
    expect(free.locked, isTrue);
    expect(free.outdatedNote, isNull);

    final premium = (await container(premium: true).read(
      explanationForQuestionProvider((Licence.pplh, 'PL010-0002')).future,
    ))!;
    expect(premium.locked, isFalse);
    expect(premium.outdatedNote, contains('§ 31'));

    // PPL(A) links the outdated key too and AL01 lists it first; the free
    // three are unchanged (unfiltered, PL010-0003 would be the 4th).
    final c = container();
    expect(await lockedOf(c, Licence.ppla, ['PL010-0003', 'PL010-0004']), {
      'PL010-0003': false,
      'PL010-0004': true,
    });
    expect(
      (await c.read(
        explanationForQuestionProvider((Licence.ppla, 'PL010-0011')).future,
      ))!.outdated,
      isTrue,
    );
  });

  test('a key with an explanation and an outdated note: a free user gets the '
      'free explanation and the mark, never the note', () async {
    final free = (await container().read(
      explanationForQuestionProvider((Licence.pplh, 'PL010-0009')).future,
    ))!;
    expect(free.locked, isFalse);
    expect(free.hasExplanation, isTrue);
    expect(free.text, isNotEmpty);
    expect(free.outdated, isTrue);
    expect(free.outdatedNote, isNull);

    final premium = (await container(premium: true).read(
      explanationForQuestionProvider((Licence.pplh, 'PL010-0009')).future,
    ))!;
    expect(premium.outdatedNote, 'Notatka o zmianie przepisów dla K9.');
  });

  test('premium sees every explanation', () async {
    final c = container(premium: true);
    final locked = await lockedOf(c, Licence.ppla, [
      'PL010-0001',
      'PL010-0004',
      'PL010-0005',
    ]);
    expect(locked.values, everyElement(isFalse));
  });

  test('SPL has no first two keys of the topic: the next three present ones '
      'are free', () async {
    final c = container();
    expect(
      await lockedOf(c, Licence.spl, [
        'PL010-0003',
        'PL010-0004',
        'PL010-0005',
        'PL010-0006',
      ]),
      {
        'PL010-0003': false,
        'PL010-0004': false,
        'PL010-0005': false,
        'PL010-0006': true,
      },
    );
  });

  test('the free set does not depend on what was opened before', () async {
    final c = container();
    // Opening the locked one first does not change anything.
    expect(await lockedOf(c, Licence.ppla, ['PL010-0004']), {
      'PL010-0004': true,
    });
    expect(await lockedOf(c, Licence.ppla, ['PL010-0001', 'PL010-0004']), {
      'PL010-0001': false,
      'PL010-0004': true,
    });
  });

  test('questions of other subjects never read the materials', () async {
    final bundle = MaterialsBundle();
    final c = ProviderContainer(
      overrides: [
        purchaseServiceProvider.overrideWithValue(FakePurchaseService()),
        materialsRepositoryProvider.overrideWithValue(
          materialsRepository(bundle),
        ),
      ],
    );
    addTearDown(c.dispose);
    expect(
      await c.read(
        explanationForQuestionProvider((Licence.ppla, 'PL050-0001')).future,
      ),
      isNull,
    );
    expect(bundle.reads, isEmpty);
  });

  test('summaries: the first section of a topic is free, the others are '
      'Premium', () async {
    final free = await container().read(
      summariesProvider((Licence.ppla, SubjectId.airLaw)).future,
    );
    expect(free!.topics.map((t) => t.topic.id), ['AL01', 'AL02']);
    expect(free.topic('AL01')!.sections.map((s) => s.locked), [false, true]);
    expect(free.topic('AL02')!.sections.map((s) => s.locked), [false]);
    expect(free.topic('AL01')!.sections.first.questionIds, [
      'PL010-0001',
      'PL010-0003',
    ]);
    expect(free.legalStateAsOf, DateTime(2026, 10, 1));

    final premium = await container(premium: true)
        .read(summariesProvider((Licence.ppla, SubjectId.airLaw)).future);
    expect(premium!.topic('AL01')!.sections.map((s) => s.locked), [
      false,
      false,
    ]);
  });

  group('paywall', () {
    PaywallHost.registerSetUp();

    testWidgets('opened from the materials: its own title, subtitle and the '
        'materials benefit', (tester) async {
      final host = PaywallHost(trigger: PaywallTrigger.materials);
      await host.open(tester);
      expect(find.byType(PaywallScreen), findsOneWidget);
      expect(
        find.text('Explanations and study notes are part of Premium'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Free access opens ${AccessPolicy.freeExplanationsPerTopic} '
          'explanations per topic and the first section of every summary.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Explanations of the questions and study notes (air law)'),
        findsOneWidget,
      );
    });

    testWidgets('Polish texts', (tester) async {
      final host = PaywallHost(
        trigger: PaywallTrigger.materials,
        locale: const Locale('pl'),
      );
      await host.open(tester);
      expect(find.text('Objaśnienia i konspekty — w Premium'), findsOneWidget);
      expect(
        find.text('Objaśnienia do pytań i konspekty (prawo lotnicze)'),
        findsOneWidget,
      );
    });

    test('the materials trigger is an explicit one', () {
      expect(PaywallTrigger.materials.isAutomatic, isFalse);
    });
  });
}
