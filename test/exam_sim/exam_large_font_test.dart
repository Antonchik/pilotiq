import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pilotiq/src/bank/models.dart';
import 'package:pilotiq/src/bank/question_bank_repository.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/progress/exam_attempt.dart';
import 'package:pilotiq/src/purchases/paywall_launcher.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';

import 'exam_helpers.dart';

/// Every screen of the exam step with large system fonts on small screens in
/// both languages, with the longest real question of the real bank: nothing
/// overflows or asserts (an exception fails the test) and every action can be
/// scrolled to, is not covered by anything and can be tapped.
///
/// The test font draws every character as a full-em square, which is wider
/// than real fonts, so this is a stricter layout than on a device. The bank
/// is read from `assets/data`; nothing depends on particular ids or counts.
void main() {
  const sizes = [Size(320, 640), Size(360, 740), Size(411, 800)];
  const scales = [1.3, 1.5, 2.0, 3.0];
  const languages = ['en', 'pl'];

  final bank = parseBank(
    File('assets/data/bank_ppla.json').readAsStringSync(),
    licence: Licence.ppla,
  );

  int weight(Question q) => [
    q.text,
    ...q.answers,
  ].fold(0, (n, t) => n + t.pl.length + (t.en ?? '').length);

  // The subject with the longest question that has enough questions for an
  // exam; the exam is made of that question and the first others.
  late final SubjectId subject;
  late final Question longest;
  late final List<Question> examQuestionsSet;
  {
    Question? best;
    for (final s in bank.subjects) {
      final qs = bank.questionsOf(s);
      if (qs.length < ExamSpec.forSubject(s).quizLength) continue;
      for (final q in qs) {
        if (best == null || weight(q) > weight(best)) best = q;
      }
    }
    longest = best!;
    subject = longest.subject;
    final spec = ExamSpec.forSubject(subject);
    final others = bank
        .questionsOf(subject)
        .where((q) => q.number != longest.number)
        .take(spec.quizLength - 1);
    examQuestionsSet = [longest, ...others];
  }

  /// Scrolls to [finder] and checks that it lies inside its scroll area and,
  /// when [action] is set, that a tap on it reaches it (nothing covers it).
  /// A control taller than its scroll area (a very long answer in the wide
  /// test font) can only be partly visible: its visible part is tapped.
  /// Returns the point to tap.
  Future<Offset> reach(
    WidgetTester tester,
    Finder finder, {
    bool action = true,
  }) async {
    final scrollables = find.byType(Scrollable);
    for (final delta in [-300.0, 300.0]) {
      for (var i = 0; i < 300 && finder.evaluate().isEmpty; i++) {
        if (scrollables.evaluate().isEmpty) break;
        await tester.drag(scrollables.last, Offset(0, delta * 2));
        await tester.pump();
      }
      if (finder.evaluate().isNotEmpty) break;
    }
    expect(finder, findsOneWidget, reason: 'not in the tree: $finder');
    final view = tester.view.physicalSize / tester.view.devicePixelRatio;
    final scrollers = find.ancestor(
      of: finder,
      matching: find.byType(Scrollable),
    );
    final area = scrollers.evaluate().isEmpty
        ? Offset.zero & view
        : tester.getRect(scrollers.first).intersect(Offset.zero & view);
    // Scroll until the control is fully inside its area, or - when it is
    // taller than the area - until a part of it is.
    for (var i = 0; i < 40 && scrollers.evaluate().isNotEmpty; i++) {
      final r = tester.getRect(finder);
      final double delta;
      if (r.height <= area.height) {
        delta = r.top < area.top - 0.5
            ? area.top - r.top
            : (r.bottom > area.bottom + 0.5 ? area.bottom - r.bottom : 0);
      } else {
        delta = (r.top - area.top).abs() < 1 ? 0 : area.top - r.top;
      }
      if (delta == 0) break;
      // The drag spends the touch slop (20) before the list starts to move.
      await tester.drag(
        scrollers.first,
        Offset(0, delta + (delta < 0 ? -20 : 20)),
      );
      await tester.pump();
    }
    final rect = tester.getRect(finder);
    final visible = rect.intersect(area);
    expect(
      visible.width > 0 && visible.height > 0,
      isTrue,
      reason: '$finder is outside of its area $area: $rect',
    );
    if (action && rect.height <= area.height) {
      expect(
        rect.top >= area.top - 0.5 && rect.bottom <= area.bottom + 0.5,
        isTrue,
        reason: '$finder is cut off by its area $area: $rect',
      );
    }
    final point = visible.center;
    if (action) {
      final hit = tester
          .hitTestOnBinding(point)
          .path
          .any((e) => identical(e.target, tester.renderObject(finder)));
      expect(hit, isTrue, reason: '$finder is covered at $point');
    }
    return point;
  }

  Future<void> tapAction(WidgetTester tester, Key key) async {
    final point = await reach(tester, find.byKey(key));
    await tester.tapAt(point);
    await settle(tester);
  }

  for (final lang in languages) {
    for (final scale in scales) {
      for (final size in sizes) {
        testWidgets(
          'exam screens x$scale ${size.width.toInt()}x${size.height.toInt()} '
          '$lang',
          (tester) async {
            final h = ExamHarness()
              ..subject = subject
              ..questions = bank.questionsOf(subject);
            await h.setUp();
            addTearDown(h.tearDown);
            await Hive.box<dynamic>('config').put('questionLanguage', lang);
            Future<void> pump({bool premium = false}) => h.pump(
              tester,
              premium: premium,
              locale: Locale(lang),
              size: size,
              scale: scale,
            );

            // Rules.
            await pump();
            await h.open(tester);
            await reach(
              tester,
              find.byKey(const Key('rules_questions')),
              action: false,
            );
            await reach(
              tester,
              find.byKey(const Key('rules_time')),
              action: false,
            );
            await reach(tester, find.byKey(const Key('exam_start')));

            // The free simulation is used up.
            await h.seedAttempt(id: 'done', correct: 5, total: 12);
            await pump();
            await h.open(tester);
            await reach(tester, find.byKey(const Key('exam_limit_premium')));
            await reach(tester, find.byKey(const Key('exam_limit_back')));
            await tapAction(tester, const Key('exam_limit_history'));
            await reach(tester, find.byKey(const ValueKey('history_done')));
            await reach(
              tester,
              find.byKey(const Key('exam_history_chart')),
              action: false,
            );
            await Hive.box<dynamic>('attempts').clear();

            // An unfinished exam found at the start.
            final ids = [for (final q in examQuestionsSet) q.id];
            final start = h.now.subtract(const Duration(minutes: 2));
            await h.repo.saveInProgressAttempt(
              InProgressAttempt(
                id: 'running',
                licence: Licence.ppla,
                subject: subject,
                startedAt: start,
                durationSec: h.args.spec.minutes * 60,
                questionIds: ids,
                answers: {
                  for (final q in examQuestionsSet.skip(1).take(3)) q.id: 1,
                },
                flagged: [ids[1]],
              ),
            );
            await pump();
            await h.open(tester);
            await reach(tester, find.byKey(const Key('exam_resume_finish')));
            await tapAction(tester, const Key('exam_resume'));

            // The longest question.
            await reach(
              tester,
              find.byKey(const Key('exam_timer')),
              action: false,
            );
            await reach(
              tester,
              find.byKey(const Key('exam_position')),
              action: false,
            );
            for (var p = 0; p < 4; p++) {
              await reach(tester, find.byKey(Key('answer_$p')));
            }
            await tapAction(tester, const Key('answer_1'));
            await tapAction(tester, const Key('exam_flag'));
            await reach(tester, find.byKey(const Key('exam_next')));

            // The grid.
            await tapAction(tester, const Key('exam_grid_button'));
            for (final i in [0, 5, ids.length - 1]) {
              await reach(tester, find.byKey(Key('grid_cell_$i')));
            }
            await reach(tester, find.byKey(const Key('exam_grid_close')));
            await tapAction(tester, Key('grid_cell_${ids.length - 1}'));

            // The last question: previous and finish.
            await reach(tester, find.byKey(const Key('exam_prev')));
            await reach(tester, find.byKey(const Key('exam_finish_inline')));

            // The finish dialog.
            await tapAction(tester, const Key('exam_finish_button'));
            await reach(
              tester,
              find.byKey(const Key('exam_finish_unanswered')),
              action: false,
            );
            await reach(tester, find.byKey(const Key('exam_finish_cancel')));
            await tapAction(tester, const Key('exam_finish_cancel'));
            await tapAction(tester, const Key('exam_finish_inline'));
            await tapAction(tester, const Key('exam_finish_confirm'));

            // Result of a free user.
            await reach(
              tester,
              find.byKey(const Key('exam_result_percent')),
              action: false,
            );
            await reach(
              tester,
              find.byKey(const Key('exam_result_score')),
              action: false,
            );
            await reach(tester, find.byKey(const Key('exam_teaser_premium')));
            await reach(tester, find.byKey(const Key('exam_repeat')));
            await reach(tester, find.byKey(const Key('exam_result_history')));
            await reach(tester, find.byKey(const Key('exam_result_back')));
            await tapAction(tester, const Key('exam_teaser_premium'));
            expect(h.paywalls.last, PaywallTrigger.examResults);

            // Premium: topics, review, training.
            h.service.setEntitlement(const EntitlementState(isPremium: true));
            await settle(tester);
            await reach(tester, find.byKey(const Key('exam_train')));
            await reach(tester, find.byKey(const Key('exam_result_back')));
            await tapAction(tester, const Key('exam_review'));
            await reach(tester, find.byKey(const Key('review_filter_all')));
            await reach(tester, find.byKey(const Key('review_filter_wrong')));
            await reach(tester, find.byKey(const ValueKey('review_0')));
            await reach(
              tester,
              find.byKey(ValueKey('review_${ids.length - 1}')),
            );
            await tapAction(tester, const Key('review_filter_wrong'));
            await tester.tap(find.byType(BackButton));
            await settle(tester);
            await tapAction(tester, const Key('exam_result_history'));
            await reach(tester, find.byType(Card).first);
          },
        );
      }
    }
  }
}
