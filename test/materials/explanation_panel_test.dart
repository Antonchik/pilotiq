import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/exam_sim/exam_controller.dart';
import 'package:pilotiq/src/exam_sim/exam_review_screen.dart';
import 'package:pilotiq/src/materials/explanation_panel.dart';
import 'package:pilotiq/src/materials/report_error.dart';
import 'package:pilotiq/src/progress/exam_attempt.dart';
import 'package:pilotiq/src/progress/user_settings.dart';
import 'package:pilotiq/src/purchases/paywall_launcher.dart';
import 'package:pilotiq/src/quiz/practice/practice_screen.dart';

import 'materials_helpers.dart';

void main() {
  MaterialsHarness.registerSetUp();

  Finder key(String k) => find.byKey(Key(k));

  Widget explanationOf(
    Licence licence,
    String id, {
    QuestionLanguage language = QuestionLanguage.pl,
  }) => Scaffold(
    body: ListView(
      children: [
        QuestionExplanation(
          licence: licence,
          questionId: id,
          questionLanguage: language,
        ),
      ],
    ),
  );

  group('in practice', () {
    testWidgets('no panel before the answer; after it the text, the sources, '
        'the disclaimer and "report an error"', (tester) async {
      final h = MaterialsHarness();
      await h.pump(tester, PracticeScreen(args: learnArgs(Licence.ppla)));
      expect(find.byType(ExplanationPanel), findsNothing);
      expect(h.bundle.materialReads, 0);

      await answerCurrent(tester);
      expect(find.byType(ExplanationPanel), findsOneWidget);
      expect(
        find.text('Objaśnienie pierwsze. Odpowiedź wynika z przepisu.'),
        findsOneWidget,
      );
      expect(
        find.text('Sources: Prawo lotnicze, art. 128 ust. 1'),
        findsOneWidget,
      );
      expect(key('materials_disclaimer'), findsOneWidget);
      expect(key('explanation_report'), findsOneWidget);
      expect(key('explanation_disputed'), findsNothing);
      expect(key('explanation_polish_only'), findsNothing);
    });

    testWidgets('a question without an explanation has no panel', (
      tester,
    ) async {
      final h = MaterialsHarness();
      await h.pump(tester, PracticeScreen(args: learnArgs(Licence.ppla)));
      await answerCurrent(tester);
      await nextQuestion(tester);
      expect(find.text('Pytanie z brakiem'), findsOneWidget);
      await answerCurrent(tester);
      expect(key('practice_feedback'), findsOneWidget);
      expect(find.byType(ExplanationPanel), findsNothing);
    });

    testWidgets('free: the 4th explanation of the topic is locked and its '
        'button opens the paywall explicitly', (tester) async {
      final h = MaterialsHarness();
      await h.pump(tester, PracticeScreen(args: learnArgs(Licence.ppla)));
      // PL010-0001 (1st), PL010-0002 (none), PL010-0003 (3rd), PL010-0004.
      for (var i = 0; i < 3; i++) {
        await answerCurrent(tester);
        await nextQuestion(tester);
      }
      await answerCurrent(tester);
      expect(find.byType(ExplanationPanel), findsOneWidget);
      expect(find.text('Explanation available in Premium'), findsOneWidget);
      expect(
        find.text('Objaśnienie czwarte. Dostępne w Premium.'),
        findsNothing,
      );
      expect(key('explanation_report'), findsNothing);

      await tester.tap(key('explanation_unlock'));
      await tester.pumpAndSettle();
      expect(h.paywalls, [(PaywallTrigger.materials, true)]);
    });

    testWidgets('premium sees the 4th explanation', (tester) async {
      final h = MaterialsHarness(premium: true);
      await h.pump(tester, explanationOf(Licence.ppla, 'PL010-0004'));
      expect(
        find.text('Objaśnienie czwarte. Dostępne w Premium.'),
        findsOneWidget,
      );
      expect(key('explanation_unlock'), findsNothing);
    });
  });

  testWidgets('a disputed question shows the dispute block and its note', (
    tester,
  ) async {
    final h = MaterialsHarness();
    await h.pump(
      tester,
      explanationOf(Licence.pplh, 'PL010-0001'),
      locale: const Locale('pl'),
    );
    expect(key('explanation_disputed'), findsOneWidget);
    expect(find.text('Pytanie sporne'), findsOneWidget);
    expect(
      find.text('Według SERA.5005 poprawna może być inna odpowiedź.'),
      findsOneWidget,
    );
    expect(
      find.text('Na egzaminie liczy się odpowiedź z klucza ULC.'),
      findsOneWidget,
    );
  });

  testWidgets('free: a locked disputed question still shows the dispute '
      'mark and the ULC-key sentence, but not its note or text', (
    tester,
  ) async {
    final h = MaterialsHarness();
    await h.pump(
      tester,
      explanationOf(Licence.ppla, 'PL010-0005'),
      locale: const Locale('pl'),
    );
    expect(find.text('Objaśnienie dostępne w Premium'), findsOneWidget);
    expect(key('explanation_disputed'), findsOneWidget);
    expect(find.text('Pytanie sporne'), findsOneWidget);
    expect(
      find.text('Na egzaminie liczy się odpowiedź z klucza ULC.'),
      findsOneWidget,
    );
    expect(key('explanation_dispute_note'), findsNothing);
    expect(find.text('Notatka sporna do piątego pytania.'), findsNothing);
    expect(find.text('Objaśnienie piąte, sporne. Krótko.'), findsNothing);
    expect(key('explanation_text'), findsNothing);
    expect(key('explanation_report'), findsNothing);
    await tester.tap(key('explanation_unlock'));
    await tester.pumpAndSettle();
    expect(h.paywalls, [(PaywallTrigger.materials, true)]);
  });

  testWidgets('the disputed title is a header for screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final h = MaterialsHarness();
    await h.pump(
      tester,
      explanationOf(Licence.pplh, 'PL010-0001'),
      locale: const Locale('pl'),
    );
    expect(
      tester.getSemantics(key('explanation_disputed_title')),
      isSemantics(label: 'Pytanie sporne', isHeader: true),
    );
    handle.dispose();
  });

  testWidgets('questions in English: the "Polish only" note', (tester) async {
    final h = MaterialsHarness();
    await h.pump(
      tester,
      explanationOf(Licence.ppla, 'PL010-0001', language: QuestionLanguage.en),
    );
    expect(find.text('Explanation available in Polish only'), findsOneWidget);
  });

  testWidgets('an explanation of another licence is not shown', (tester) async {
    final h = MaterialsHarness();
    await h.pump(tester, explanationOf(Licence.bpl, 'PL010-0003'));
    expect(find.byType(ExplanationPanel), findsNothing);
  });

  group('report an error', () {
    testWidgets('no address: a dialog with the text and "copy"', (
      tester,
    ) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final h = MaterialsHarness();
      await h.pump(tester, explanationOf(Licence.ppla, 'PL010-0001'));
      await tester.tap(key('explanation_report'));
      await tester.pumpAndSettle();

      expect(h.mails, isEmpty);
      expect(key('materials_report_dialog'), findsOneWidget);
      final text = tester
          .widget<SelectableText>(key('materials_report_text'))
          .data!;
      expect(text, contains('[Pilotiq] Błąd w materiałach: $k1'));
      expect(text, contains('Pytanie: PL010-0001'));
      expect(text, contains('Licencja: ppla'));
      expect(text, contains('Wersja aplikacji: 2.0.0+15'));
      expect(text, contains('Wersja materiałów: fx123456'));
      expect(text, contains('Data bazy pytań: 01.08.2024'));

      expect(key('materials_report_copied'), findsNothing);
      await tester.tap(key('materials_report_copy'));
      await tester.pumpAndSettle();
      expect(copied, [text]);
      // The confirmation is inside the dialog, not under its barrier.
      expect(
        find.descendant(
          of: key('materials_report_dialog'),
          matching: find.text('Copied'),
        ),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);
      await tester.tap(key('materials_report_close'));
      await tester.pumpAndSettle();
      expect(key('materials_report_dialog'), findsNothing);
    });

    testWidgets('with an address: an e-mail with the subject and the body', (
      tester,
    ) async {
      final h = MaterialsHarness(email: 'errors@example.com');
      await h.pump(tester, explanationOf(Licence.ppla, 'PL010-0001'));
      await tester.tap(key('explanation_report'));
      await tester.pumpAndSettle();

      final uri = h.mails.single;
      expect(uri.scheme, 'mailto');
      expect(uri.path, 'errors@example.com');
      expect(
        uri.queryParameters['subject'],
        '[Pilotiq] Błąd w materiałach: $k1',
      );
      expect(uri.queryParameters['body'], contains('Pytanie: PL010-0001'));
      expect(key('materials_report_dialog'), findsNothing);
    });

    testWidgets('no mail app: the dialog instead', (tester) async {
      final h = MaterialsHarness(email: 'errors@example.com', mailOpens: false);
      await h.pump(tester, explanationOf(Licence.ppla, 'PL010-0001'));
      await tester.tap(key('explanation_report'));
      await tester.pumpAndSettle();
      expect(h.mails, hasLength(1));
      expect(key('materials_report_dialog'), findsOneWidget);
    });

    test('mailto is built only with an address', () {
      expect(materialReportMailto('', 's', 'b'), isNull);
      expect(materialReportMailto('a@b.c', 's t', 'x\ny')!.scheme, 'mailto');
    });
  });

  testWidgets('exam review: the explanation is under the question that has '
      'one', (tester) async {
    final h = MaterialsHarness();
    final subject = fakeSubject(Licence.ppla);
    final attempt = ExamAttempt(
      id: 'a1',
      licence: Licence.ppla,
      subject: SubjectId.airLaw,
      startedAt: DateTime(2026, 11, 24, 10),
      finishedAt: DateTime(2026, 11, 24, 10, 20),
      durationSec: 1200,
      total: 2,
      correct: 1,
      passed: false,
      reason: AttemptReason.finished,
      questionIds: const ['PL010-0001', 'PL010-0002'],
      answers: const {'PL010-0001': 0, 'PL010-0002': 1},
    );
    await h.pump(
      tester,
      ExamReviewScreen(attempt: attempt, args: ExamArgs.fromSubject(subject)),
    );
    expect(find.byType(ExplanationPanel), findsOneWidget);
    final panel = find.byType(ExplanationPanel);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('review_0')),
        matching: panel,
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('review_1')),
        matching: panel,
      ),
      findsNothing,
    );
  });
}
