import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pilotiq/src/app.dart';
import 'package:pilotiq/src/bank/question_bank_repository.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/exam_sim/exam_entry.dart';
import 'package:pilotiq/src/exam_sim/exam_history_screen.dart';
import 'package:pilotiq/src/purchases/paywall_launcher.dart';
import 'package:pilotiq/src/purchases/paywall_screen.dart';
import 'package:pilotiq/src/quiz/practice/practice_controller.dart';
import 'package:pilotiq/src/quiz/practice/practice_screen.dart';
import 'package:pilotiq/src/quiz/practice/practice_session.dart';

import '../bank/fake_bank.dart';
import '../dashboard/dashboard_helpers.dart';
import '../exam_sim/exam_helpers.dart';
import 'paywall_helpers.dart';

Finder _key(String k) => find.byKey(Key(k));

/// The real paywall opener inside a scope: the harnesses of the other tests
/// replace it by a recorder.
Widget _realPaywall(Widget child) => ProviderScope(
  overrides: [paywallOpenerProvider.overrideWith(realPaywallOpener)],
  child: child,
);

Future<void> _buyLifetime(WidgetTester tester) async {
  expect(find.byType(PaywallScreen), findsOneWidget);
  await tester.tap(_key('paywall_plan_lifetime'));
  await tester.pump();
  await tester.tap(_key('paywall_buy'));
  await tester.pumpAndSettle();
  expect(find.text('Thank you!'), findsOneWidget);
  await tester.tap(_key('paywall_done'));
  await tester.pumpAndSettle();
  expect(find.byType(PaywallScreen), findsNothing);
}

void main() {
  group('exam simulation limit', () {
    final h = ExamHarness();
    setUp(h.setUp);
    tearDown(h.tearDown);

    Widget openButton() => Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            key: const Key('open_exam'),
            onPressed: () => openExamSimulation(context, h.args),
            child: const Text('open'),
          ),
        ),
      ),
    );

    testWidgets('the button on the limit screen opens the paywall even with '
        'no answers at all, and buying lets the user start', (tester) async {
      await h.seedAttempt(); // one finished simulation, no answers in the stats
      await h.pump(tester, home: _realPaywall(openButton()));
      await h.open(tester);

      // The automatic call waits for 10 answers: nothing opened by itself.
      expect(find.byType(PaywallScreen), findsNothing);
      expect(find.text('Free simulation used'), findsOneWidget);

      await tester.tap(_key('exam_limit_premium'));
      await tester.pumpAndSettle();
      expect(find.text('The free simulation is used'), findsOneWidget);

      await _buyLifetime(tester);
      // The original action continues without a restart.
      expect(_key('exam_start'), findsOneWidget);
    });

    testWidgets('the result teaser: buy, come back, the teaser is gone', (
      tester,
    ) async {
      await h.seedAttempt();
      await h.pump(tester, home: _realPaywall(ExamHistoryScreen(args: h.args)));
      await tester.tap(find.byKey(const ValueKey('history_review')));
      await settle(tester);
      expect(_key('exam_result_teaser'), findsOneWidget);

      await tester.tap(_key('exam_teaser_premium'));
      await tester.pumpAndSettle();
      expect(find.text('Topic breakdown is part of Premium'), findsOneWidget);
      await _buyLifetime(tester);
      expect(_key('exam_result_teaser'), findsNothing);
    });

    testWidgets('losing Premium on the result and review screens does not '
        'crash', (tester) async {
      await h.seedAttempt();
      await h.pump(
        tester,
        premium: true,
        home: ExamHistoryScreen(args: h.args),
      );
      await tester.tap(find.byKey(const ValueKey('history_review')));
      await settle(tester);
      expect(_key('exam_result_teaser'), findsNothing);

      h.service.loseEntitlement();
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(_key('exam_result_teaser'), findsOneWidget);
    });
  });

  group('dashboard readiness', () {
    AppHarness.registerSetUp();

    Future<AppHarness> pumpDashboard(
      WidgetTester tester, {
      bool premium = false,
    }) async {
      final h = AppHarness(premium: premium);
      await h.seedConfig();
      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: h.overrides,
          child: _realPaywall(const MyApp()),
        ),
      );
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets('the locked card opens the paywall; buying shows the detail', (
      tester,
    ) async {
      await pumpDashboard(tester);
      expect(_key('readiness_air_law'), findsNothing);
      await tester.tap(_key('dashboard_readiness'));
      await tester.pumpAndSettle();
      await _buyLifetime(tester);
      expect(_key('readiness_air_law'), findsOneWidget);
    });

    testWidgets('losing Premium locks the detail again without a crash', (
      tester,
    ) async {
      final h = await pumpDashboard(tester, premium: true);
      expect(_key('readiness_air_law'), findsOneWidget);
      h.purchases.loseEntitlement();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_key('readiness_air_law'), findsNothing);
      expect(_key('dashboard_readiness_locked'), findsOneWidget);
    });
  });

  group('daily limit window', () {
    PaywallHost.registerSetUp();

    testWidgets('the limit opens the paywall by itself; buying lets the user '
        'go on answering', (tester) async {
      final host = PaywallHost();
      final questions = parseBank(
        fakeBankJson(Licence.ppla),
        licence: Licence.ppla,
      ).questionsOf(SubjectId.airLaw);
      for (var i = 0; i < 20; i++) {
        await host.repository.recordAnswer(
          Licence.ppla,
          'old$i',
          true,
          paywallTestNow,
        );
      }
      host.configureView(tester);
      await tester.pumpWidget(
        host.app(
          extra: [
            questionBankRepositoryProvider.overrideWithValue(
              fakeBankRepository(),
            ),
            paywallOpenerProvider.overrideWith(realPaywallOpener),
          ],
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open_practice'),
                  onPressed: () => openPractice(
                    context,
                    PracticeArgs(
                      licence: Licence.ppla,
                      subject: SubjectId.airLaw,
                      mode: PracticeMode.learn,
                      questions: questions,
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(_key('open_practice'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('AGL'));
      await tester.pumpAndSettle();
      // 20 answers are given: the paywall opened by itself.
      expect(find.text("Today's free limit is used up"), findsOneWidget);
      await _buyLifetime(tester);

      expect(_key('practice_limit'), findsNothing);
      await tester.tap(find.text('AGL'));
      await tester.pumpAndSettle();
      expect(find.byType(PracticeScreen), findsOneWidget);
      expect(find.byType(PaywallScreen), findsNothing);
      expect((await host.repository.dailyStat(paywallTestNow)).answered, 21);
    });
  });

  tearDownAll(() async {
    await Hive.close();
  });
}
