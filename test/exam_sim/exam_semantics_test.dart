import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilotiq/src/localization/generated/app_localizations_en.dart';
import 'package:pilotiq/src/localization/generated/app_localizations_pl.dart';

import 'exam_helpers.dart';

void main() {
  late ExamHarness h;

  setUp(() async {
    h = ExamHarness();
    await h.setUp();
  });

  tearDown(() => h.tearDown());

  testWidgets('answers, grid cells and the clock have useful semantics; the '
      'clock is not a live region', (tester) async {
    final handle = tester.ensureSemantics();
    await h.pump(tester);
    await h.open(tester);
    await h.start(tester);
    await tester.tap(find.byKey(const Key('answer_1')));
    await settle(tester);

    final answer = tester.getSemantics(find.byKey(const Key('answer_1')));
    expect(answer.label, startsWith('Answer 2 of 4: '));
    // ignore: deprecated_member_use
    expect(answer.hasFlag(SemanticsFlag.isChecked), isTrue);
    // ignore: deprecated_member_use
    expect(answer.hasFlag(SemanticsFlag.isInMutuallyExclusiveGroup), isTrue);
    final other = tester.getSemantics(find.byKey(const Key('answer_0')));
    // ignore: deprecated_member_use
    expect(other.hasFlag(SemanticsFlag.isChecked), isFalse);

    final timer = tester.getSemantics(find.byKey(const Key('exam_timer')));
    expect(timer.label, '30 minutes left');
    // ignore: deprecated_member_use
    expect(timer.hasFlag(SemanticsFlag.isLiveRegion), isFalse);
    await h.advance(tester, const Duration(seconds: 30));
    expect(
      tester.getSemantics(find.byKey(const Key('exam_timer'))).label,
      '30 minutes left',
      reason: 'the label changes only when the whole minute changes',
    );

    await tester.tap(find.byKey(const Key('exam_flag')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('exam_grid_button')));
    await settle(tester);
    final cell = tester.getSemantics(find.byKey(const Key('grid_cell_0')));
    expect(cell.label, contains('Question 1'));
    expect(cell.label, contains('answered'));
    expect(cell.label, contains('marked to come back'));
    expect(cell.label, contains('current question'));
    expect(
      tester.getSemantics(find.byKey(const Key('grid_cell_3'))).label,
      'Question 4, not answered',
    );
    handle.dispose();
  });

  test('numbers use the plural forms of English and Polish', () {
    final en = AppLocalizationsEn();
    final pl = AppLocalizationsPl();
    expect(en.examFinishUnanswered(1), '1 question is not answered.');
    expect(en.examFinishUnanswered(2), '2 questions are not answered.');
    expect(
      pl.examFinishUnanswered(0),
      'Na wszystkie pytania udzielono odpowiedzi.',
    );
    expect(pl.examFinishUnanswered(1), '1 pytanie bez odpowiedzi.');
    expect(pl.examFinishUnanswered(2), '2 pytania bez odpowiedzi.');
    expect(pl.examFinishUnanswered(5), '5 pytań bez odpowiedzi.');
    expect(pl.examFinishUnanswered(22), '22 pytania bez odpowiedzi.');
    expect(pl.examRulesQuestions(12), '12 pytań');
    expect(pl.examRulesTime(1), 'Limit czasu: 1 minuta');
    expect(pl.examRulesTime(30), 'Limit czasu: 30 minut');
    expect(pl.examTimeLeftSemantics(3), 'Pozostało 3 minuty');
  });
}
