import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pilotiq/src/app.dart';
import 'package:pilotiq/src/bank/models.dart';
import 'package:pilotiq/src/bank/question_bank_repository.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/progress/providers.dart';
import 'package:pilotiq/src/purchases/disabled_purchase_service.dart';
import 'package:pilotiq/src/purchases/fake_purchase_service.dart';
import 'package:pilotiq/src/purchases/paywall_screen.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';
import 'package:pilotiq/src/quiz/practice/practice_screen.dart';
import 'package:pilotiq/src/quiz/quiz_list.dart';
import 'package:pilotiq/src/subjects/subject_info.dart';

import '../bank/fake_bank.dart';
import '../bank/memory_hive.dart';
import 'paywall_helpers.dart';

Finder _key(String k) => find.byKey(Key(k));

void main() {
  PaywallHost.registerSetUp();

  group('a locked mode opens without a restart after the purchase', () {
    late List<Question> questions;

    setUp(() {
      questions = parseBank(
        fakeBankJson(Licence.ppla),
        licence: Licence.ppla,
      ).questionsOf(SubjectId.airLaw);
    });

    SubjectInfo subject() => SubjectInfo(
      licence: Licence.ppla,
      id: SubjectId.airLaw,
      title: 'Air law',
      description: '',
      spec: ExamSpec.forSubject(SubjectId.airLaw, licence: Licence.ppla),
      questions: questions,
    );

    testWidgets('buy lifetime, close, open My mistakes', (tester) async {
      final host = PaywallHost(
        service: FakePurchaseService(
          offering: FakePurchaseService.storeLikeOffering,
        ),
      );
      host.configureView(tester);
      await tester.pumpWidget(
        host.app(
          home: Scaffold(
            body: SingleChildScrollView(child: QuizList(subject: subject())),
          ),
          extra: [
            questionBankRepositoryProvider.overrideWithValue(
              fakeBankRepository(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Locked: the tile opens the real paywall.
      await tester.tap(_key('mode_mistakes'));
      await tester.pumpAndSettle();
      expect(find.byType(PaywallScreen), findsOneWidget);
      expect(find.byType(PracticeScreen), findsNothing);

      await tester.tap(_key('paywall_plan_lifetime'));
      await tester.pump();
      await tester.tap(_key('paywall_buy'));
      await tester.pumpAndSettle();
      expect(find.text('Thank you!'), findsOneWidget);
      await tester.tap(_key('paywall_done'));
      await tester.pumpAndSettle();

      // Unlocked in the same session: no lock badge, the mode opens.
      expect(find.byType(PaywallScreen), findsNothing);
      expect(find.text('Premium'), findsNothing);
      await tester.tap(_key('mode_mistakes'));
      await tester.pumpAndSettle();
      expect(find.byType(PaywallScreen), findsNothing);
      expect(find.byType(PracticeScreen), findsOneWidget);
    });

    testWidgets(
      'losing the entitlement mid-session locks again, without a crash',
      (tester) async {
        final service = FakePurchaseService(premium: true);
        final host = PaywallHost(service: service);
        host.configureView(tester);
        await tester.pumpWidget(
          host.app(
            home: Scaffold(
              body: SingleChildScrollView(child: QuizList(subject: subject())),
            ),
            extra: [
              questionBankRepositoryProvider.overrideWithValue(
                fakeBankRepository(),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Premium'), findsNothing);

        service.loseEntitlement(); // refund, expiry or revoked on the server
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Premium'), findsNWidgets(2));

        // The next action meets the paywall.
        await tester.tap(_key('mode_mistakes'));
        await tester.pumpAndSettle();
        expect(find.byType(PaywallScreen), findsOneWidget);
        expect(find.byType(PracticeScreen), findsNothing);
      },
    );
  });

  group('a build without store keys', () {
    setUp(() {
      PackageInfo.setMockInitialValues(
        appName: 'Pilotiq',
        packageName: 'antonchik.anton.pilotiq',
        version: '2.0.0',
        buildNumber: '15',
        buildSignature: '',
      );
    });

    testWidgets('the app starts and the paywall says "not available"', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await Hive.box<dynamic>('config').put('onboardingDone', true);
      // No override of the purchase service: the default of a build without keys.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            progressRepositoryProvider.overrideWithValue(
              memoryProgressRepository(),
            ),
            questionBankRepositoryProvider.overrideWithValue(
              fakeBankRepository(),
            ),
          ],
          child: const MyApp(),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MyApp)),
      );
      expect(
        container.read(purchaseServiceProvider),
        isA<DisabledPurchaseService>(),
      );
      expect(container.read(isPremiumProvider), isFalse);

      await tester.tap(_key('tab_profile'));
      await tester.pumpAndSettle();
      await tester.tap(_key('settings_premium'));
      await tester.pumpAndSettle();

      expect(find.byType(PaywallScreen), findsOneWidget);
      expect(_key('paywall_unavailable'), findsOneWidget);
      expect(
        find.text('Purchases are not available in this build of the app.'),
        findsOneWidget,
      );
      expect(_key('paywall_buy'), findsNothing);
    });
  });
}
