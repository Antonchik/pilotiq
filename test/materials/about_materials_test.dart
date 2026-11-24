import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilotiq/src/about/about.dart';

import 'materials_helpers.dart';

/// The About screen states the disclaimer of the study materials and the date
/// of their legal state (from the materials asset).
void main() {
  MaterialsHarness.registerSetUp();

  for (final (locale, disclaimer, legalState) in [
    (
      const Locale('pl'),
      'Materiały nie zastępują szkolenia w ATO/DTO ani aktualnych przepisów.',
      'Stan prawny na 01.10.2026',
    ),
    (
      const Locale('en'),
      'The materials do not replace training at an ATO/DTO or the current '
          'regulations.',
      'Legal state as of 01.10.2026',
    ),
  ]) {
    testWidgets('${locale.languageCode}: disclaimer and legal state', (
      tester,
    ) async {
      final h = MaterialsHarness();
      await h.pump(tester, const AboutScreen(), locale: locale);
      final block = find.byKey(const Key('about_materials'));
      await tester.scrollUntilVisible(block, 200);
      for (final text in [disclaimer, legalState]) {
        expect(
          find.descendant(of: block, matching: find.text(text)),
          findsOneWidget,
        );
      }
      expect(h.bundle.materialReads, 1);
    });
  }

  testWidgets('without materials: the disclaimer, no date', (tester) async {
    final h = MaterialsHarness(bundle: MaterialsBundle.missing());
    await h.pump(tester, const AboutScreen(), locale: const Locale('pl'));
    final block = find.byKey(const Key('about_materials'));
    await tester.scrollUntilVisible(block, 200);
    expect(block, findsOneWidget);
    expect(find.textContaining('Stan prawny na'), findsNothing);
  });
}
