import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/materials/explanation_panel.dart';
import 'package:pilotiq/src/materials/materials_screen.dart';
import 'package:pilotiq/src/materials/summary_screen.dart';
import 'package:pilotiq/src/progress/user_settings.dart';
import 'package:pilotiq/src/quiz/practice/practice_screen.dart';

import '../onboarding/large_font_helpers.dart';
import 'materials_helpers.dart';

/// The explanation panel (open, locked, disputed), the study notes and a
/// summary with large system fonts on small screens in both languages, with
/// the matrix and the helpers of `test/onboarding/large_font_test.dart`:
/// nothing overflows (an exception fails the test) and every action can be
/// scrolled to and tapped.
void main() {
  MaterialsHarness.registerSetUp();

  Finder key(String k) => find.byKey(Key(k));

  for (final lang in largeFontLanguages) {
    for (final scale in largeFontScales) {
      for (final size in largeFontSizes) {
        final name =
            '$lang x$scale ${size.width.toInt()}x${size.height.toInt()}';

        void screen(
          String title,
          Future<void> Function(WidgetTester tester) body,
        ) {
          testWidgets('$title: $name', (tester) async {
            configure(tester, lang, scale, size);
            await body(tester);
          });
        }

        Future<void> pump(
          WidgetTester tester,
          MaterialsHarness h,
          Widget home,
        ) => h.pump(tester, home, locale: null, sized: false);

        screen('explanation after an answer', (tester) async {
          final h = MaterialsHarness();
          await pump(tester, h, PracticeScreen(args: learnArgs(Licence.ppla)));
          await reach(tester, key('answer_0'));
          await reach(tester, key('explanation_text'), tap: false);
          await reach(tester, key('explanation_refs'), tap: false);
          await reach(tester, key('explanation_report'));
          await reach(tester, key('materials_report_copy'));
          await reach(tester, key('materials_report_close'));
          await reach(tester, key('practice_next'), tap: false);
        });

        screen('disputed explanation', (tester) async {
          final h = MaterialsHarness();
          await pump(tester, h, PracticeScreen(args: learnArgs(Licence.pplh)));
          await reach(tester, key('answer_0'));
          await reach(tester, key('explanation_dispute_note'), tap: false);
          await reach(tester, key('explanation_report'), tap: false);
        });

        screen('locked explanation, questions in English', (tester) async {
          final h = MaterialsHarness();
          await pump(
            tester,
            h,
            Scaffold(
              appBar: AppBar(title: const Text('Practice')),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  QuestionExplanation(
                    licence: Licence.ppla,
                    questionId: 'PL010-0004',
                    questionLanguage: QuestionLanguage.en,
                  ),
                ],
              ),
            ),
          );
          await reach(tester, key('explanation_polish_only'), tap: false);
          await reach(tester, key('explanation_unlock'));
          expect(h.paywalls, hasLength(1));
        });

        screen('study notes', (tester) async {
          final h = MaterialsHarness();
          await pump(
            tester,
            h,
            MaterialsScreen(subject: fakeSubject(Licence.ppla)),
          );
          await reach(tester, key('materials_disclaimer'), tap: false);
          await reach(tester, key('materials_topic_AL02'), tap: false);
          await reach(tester, key('materials_topic_AL01'));
          expect(find.byType(SummaryScreen), findsOneWidget);
        });

        screen('summary', (tester) async {
          final h = MaterialsHarness();
          await pump(
            tester,
            h,
            SummaryScreen(subject: fakeSubject(Licence.ppla), topicId: 'AL01'),
          );
          await reach(tester, key('summary_report_AL01-1'), tap: false);
          await reach(tester, key('summary_unlock_AL01-2'));
          expect(h.paywalls, hasLength(1));
          await reach(tester, key('summary_questions_AL01-2'), tap: false);
          await reach(tester, key('summary_questions_AL01-1'));
          expect(find.byType(PracticeScreen), findsOneWidget);
        });
      }
    }
  }
}
