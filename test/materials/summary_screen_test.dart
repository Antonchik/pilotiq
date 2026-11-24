import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/materials/materials_screen.dart';
import 'package:pilotiq/src/materials/summary_screen.dart';
import 'package:pilotiq/src/purchases/paywall_launcher.dart';
import 'package:pilotiq/src/quiz/practice/practice_screen.dart';
import 'package:pilotiq/src/quiz/practice/practice_session.dart';
import 'package:pilotiq/src/subjects/subject_info.dart';
import 'package:pilotiq/src/subjects/subject_screen.dart';

import 'materials_helpers.dart';

void main() {
  MaterialsHarness.registerSetUp();

  Finder key(String k) => find.byKey(Key(k));

  testWidgets('the subject screen offers the study notes of air law without '
      'reading them; the notes list the topics with the disclaimer and the '
      'legal state', (tester) async {
    final h = MaterialsHarness();
    await h.pump(
      tester,
      SubjectScreen(subject: fakeSubject(Licence.ppla)),
      locale: const Locale('pl'),
    );
    expect(h.bundle.materialReads, 0);
    await tester.scrollUntilVisible(key('mode_materials'), 200);
    await tester.tap(key('mode_materials'));
    await tester.pumpAndSettle();

    expect(find.byType(MaterialsScreen), findsOneWidget);
    expect(h.bundle.materialReads, 1);
    expect(
      find.text(
        'Materiały nie zastępują szkolenia w ATO/DTO ani aktualnych przepisów.',
      ),
      findsOneWidget,
    );
    expect(find.text('Stan prawny na 01.10.2026'), findsOneWidget);
    expect(key('materials_topic_AL01'), findsOneWidget);
    expect(key('materials_topic_AL02'), findsOneWidget);
    expect(find.text('Licencje i uprawnienia'), findsOneWidget);
    expect(find.text('2 rozdziały'), findsOneWidget);
  });

  testWidgets('another subject has no study notes tile', (tester) async {
    final h = MaterialsHarness();
    await h.pump(
      tester,
      SubjectScreen(
        subject: SubjectInfo(
          licence: Licence.ppla,
          id: SubjectId.meteorology,
          title: 'Meteorology',
          description: '',
          spec: ExamSpec.forSubject(
            SubjectId.meteorology,
            licence: Licence.ppla,
          ),
          questions: const [],
        ),
      ),
    );
    expect(key('mode_materials'), findsNothing);
  });

  testWidgets('a summary: the free section with sources and report, the '
      'locked one with a teaser that opens the paywall', (tester) async {
    final h = MaterialsHarness();
    await h.pump(tester, MaterialsScreen(subject: fakeSubject(Licence.ppla)));
    await tester.tap(key('materials_topic_AL01'));
    await tester.pumpAndSettle();

    expect(find.byType(SummaryScreen), findsOneWidget);
    expect(find.text('Licencja pilota'), findsOneWidget);
    expect(
      find.text('Pierwszy akapit konspektu o licencjach.'),
      findsOneWidget,
    );
    expect(find.text('pierwszy punkt listy'), findsOneWidget);
    expect(
      find.text('Sources: Prawo lotnicze, art. 95 ust. 1'),
      findsOneWidget,
    );
    expect(key('summary_report_AL01-1'), findsOneWidget);

    expect(key('summary_locked_AL01-2'), findsOneWidget);
    expect(
      find.text('Treść drugiego rozdziału, dostępna w Premium.'),
      findsNothing,
    );
    expect(key('summary_report_AL01-2'), findsNothing);
    await tester.tap(key('summary_unlock_AL01-2'));
    await tester.pumpAndSettle();
    expect(h.paywalls, [(PaywallTrigger.materials, true)]);
  });

  testWidgets('premium sees every section', (tester) async {
    final h = MaterialsHarness(premium: true);
    await h.pump(
      tester,
      SummaryScreen(subject: fakeSubject(Licence.ppla), topicId: 'AL01'),
    );
    expect(
      find.text('Treść drugiego rozdziału, dostępna w Premium.'),
      findsOneWidget,
    );
    expect(key('summary_unlock_AL01-2'), findsNothing);
  });

  testWidgets('"report an error" of a section: a dialog with its id', (
    tester,
  ) async {
    final h = MaterialsHarness();
    await h.pump(
      tester,
      SummaryScreen(subject: fakeSubject(Licence.ppla), topicId: 'AL01'),
    );
    await tester.tap(key('summary_report_AL01-1'));
    await tester.pumpAndSettle();
    final text = tester
        .widget<SelectableText>(key('materials_report_text'))
        .data!;
    expect(text, contains('[Pilotiq] Błąd w materiałach: AL01-1'));
    expect(text, contains('Licencja: ppla'));
  });

  testWidgets('"questions of this topic" opens practice with exactly the '
      'questions of the section', (tester) async {
    final h = MaterialsHarness();
    await h.pump(
      tester,
      SummaryScreen(subject: fakeSubject(Licence.ppla), topicId: 'AL01'),
    );
    expect(find.text('Questions of this topic (2)'), findsOneWidget);
    await tester.tap(key('summary_questions_AL01-1'));
    await tester.pumpAndSettle();

    final screen = tester.widget<PracticeScreen>(find.byType(PracticeScreen));
    expect(screen.args.mode, PracticeMode.retry);
    expect(screen.args.retryIds, ['PL010-0001', 'PL010-0003']);
    expect(screen.args.licence, Licence.ppla);
    expect(find.text('Licencja pilota'), findsWidgets);
    expect(find.text('Wysokość nad ziemią to'), findsOneWidget);

    // The two questions and then the summary of the session.
    await answerCurrent(tester);
    await nextQuestion(tester);
    expect(find.text('Only in Polish'), findsNothing);
    expect(find.text('Tylko po polsku'), findsOneWidget);
    await answerCurrent(tester);
    await nextQuestion(tester);
    expect(key('practice_next'), findsNothing);
  });

  testWidgets('a broken asset: "no materials" without an exception', (
    tester,
  ) async {
    final h = MaterialsHarness(bundle: MaterialsBundle('{"schema": 1, "sub'));
    await h.pump(
      tester,
      MaterialsScreen(subject: fakeSubject(Licence.ppla)),
      locale: const Locale('pl'),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Brak materiałów dla tego przedmiotu.'), findsOneWidget);
    expect(h.logs, hasLength(1));

    await h.pump(
      tester,
      SummaryScreen(subject: fakeSubject(Licence.ppla), topicId: 'AL01'),
    );
    expect(key('materials_empty'), findsOneWidget);
  });

  testWidgets('a missing asset: "no materials"', (tester) async {
    final h = MaterialsHarness(bundle: MaterialsBundle.missing());
    await h.pump(tester, MaterialsScreen(subject: fakeSubject(Licence.ppla)));
    expect(key('materials_empty'), findsOneWidget);
  });

  testWidgets('BPL has no linked questions: no questions button', (
    tester,
  ) async {
    final h = MaterialsHarness();
    await h.pump(
      tester,
      SummaryScreen(subject: fakeSubject(Licence.bpl), topicId: 'AL01'),
    );
    expect(key('summary_questions_AL01-1'), findsNothing);
    expect(find.text('Licencja pilota'), findsOneWidget);
  });
}
