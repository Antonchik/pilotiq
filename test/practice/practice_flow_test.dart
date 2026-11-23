import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pilotiq/src/bank/models.dart';
import 'package:pilotiq/src/bank/question_bank_repository.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/progress/progress_repository.dart';
import 'package:pilotiq/src/progress/providers.dart';
import 'package:pilotiq/src/purchases/fake_purchase_service.dart';
import 'package:pilotiq/src/purchases/paywall_launcher.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';
import 'package:pilotiq/src/quiz/practice/practice_controller.dart';
import 'package:pilotiq/src/quiz/practice/practice_screen.dart';
import 'package:pilotiq/src/quiz/practice/practice_session.dart';
import 'package:pilotiq/src/quiz/quiz_list.dart';
import 'package:pilotiq/src/subjects/subject_info.dart';

import '../bank/fake_bank.dart';
import '../bank/memory_hive.dart';

/// A [Random] that makes `List.shuffle` keep the order of the list.
class _NoShuffleRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => max - 1;
}

final _now = DateTime(2026, 5, 1, 12);

void main() {
  late ProgressRepository repo;
  late List<PaywallTrigger> paywalls;
  late List<Question> questions;

  setUp(() async {
    await openMemoryBox('config');
    repo = memoryProgressRepository();
    paywalls = [];
    questions = parseBank(
      fakeBankJson(Licence.ppla),
      licence: Licence.ppla,
    ).questionsOf(SubjectId.airLaw);
  });

  tearDown(() async {
    await Hive.close();
  });

  PracticeArgs args(PracticeMode mode) => PracticeArgs(
    licence: Licence.ppla,
    subject: SubjectId.airLaw,
    mode: mode,
    questions: questions,
  );

  SubjectInfo subjectInfo() => SubjectInfo(
    licence: Licence.ppla,
    id: SubjectId.airLaw,
    title: 'Air law',
    description: '',
    spec: ExamSpec.forSubject(SubjectId.airLaw, licence: Licence.ppla),
    questions: questions,
  );

  /// Pumps a host app with a button that opens the practice screen of
  /// [mode]; [home] replaces it when given.
  Future<void> pumpApp(
    WidgetTester tester, {
    PracticeMode mode = PracticeMode.learn,
    bool premium = false,
    Widget? home,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          purchaseServiceProvider.overrideWithValue(
            FakePurchaseService(premium: premium),
          ),
          progressRepositoryProvider.overrideWithValue(repo),
          questionBankRepositoryProvider.overrideWithValue(
            fakeBankRepository(),
          ),
          clockProvider.overrideWithValue(Clock.fixed(_now)),
          randomProvider.overrideWithValue(_NoShuffleRandom()),
          paywallOpenerProvider.overrideWithValue((context, trigger) async {
            paywalls.add(trigger);
          }),
        ],
        child: _Host(mode: mode, args: args, home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openPracticeScreen(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('open_practice')));
    await tester.pumpAndSettle();
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('practice_next')));
    await tester.pumpAndSettle();
  }

  group('answering', () {
    testWidgets('a correct answer is stored: correct 1, box 2', (tester) async {
      await pumpApp(tester);
      await openPracticeScreen(tester);

      await tester.tap(find.text('AGL'));
      await tester.pumpAndSettle();

      final p = (await repo.progressOf(Licence.ppla, 'PL010-0001'))!;
      expect(p.correct, 1);
      expect(p.wrong, 0);
      expect(p.box, 2);
      expect(find.text('Correct!'), findsOneWidget);
      expect((await repo.dailyStat(_now)).answered, 1);
    });

    testWidgets('a wrong answer highlights the correct one and becomes a '
        'mistake', (tester) async {
      await pumpApp(tester, premium: true);
      await openPracticeScreen(tester);

      await tester.tap(find.text('AMSL'));
      await tester.pumpAndSettle();

      final p = (await repo.progressOf(Licence.ppla, 'PL010-0001'))!;
      expect(p.wrong, 1);
      expect(p.correct, 0);
      expect(p.box, 1);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsOneWidget);
      expect(
        find.text('Wrong. The correct answer is highlighted.'),
        findsOneWidget,
      );

      // The question shows up in the mistakes mode.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await pumpMode(tester, PracticeMode.mistakes);
      expect(find.text('Wysokość nad ziemią to'), findsOneWidget);
    });

    testWidgets('a double tap writes one record', (tester) async {
      await pumpApp(tester);
      await openPracticeScreen(tester);

      await tester.tap(find.text('AGL'));
      await tester.tap(find.text('AGL'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('AGL'));
      await tester.tap(find.text('AMSL'));
      await tester.pumpAndSettle();

      final p = (await repo.progressOf(Licence.ppla, 'PL010-0001'))!;
      expect(p.seen, 1);
      expect(p.wrong, 0);
      expect((await repo.dailyStat(_now)).answered, 1);
    });

    testWidgets('a rebuild keeps the session: no duplicated or reshuffled '
        'questions', (tester) async {
      await pumpApp(tester);
      await openPracticeScreen(tester);
      await tester.tap(find.text('AGL'));
      await tester.pumpAndSettle();
      await next(tester);
      expect(find.byKey(const Key('practice_progress')), findsOneWidget);
      expect(find.text('1 / 4'), findsOneWidget);
      expect(find.text('Pytanie z brakiem'), findsOneWidget);

      // Rebuild everything with another theme and from a new widget tree
      // state (the theme switch rebuilds the whole subtree).
      _hostKey.currentState!.toggleTheme();
      await tester.pumpAndSettle();

      expect(find.text('1 / 4'), findsOneWidget);
      expect(find.text('Pytanie z brakiem'), findsOneWidget);
      await tester.tap(find.text('Odpowiedź pierwsza'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 4'), findsOneWidget);
      expect((await repo.progressOf(Licence.ppla, 'PL010-0002'))!.seen, 1);
      expect((await repo.dailyStat(_now)).answered, 2);
    });

    testWidgets('closing and reopening continues with unseen questions', (
      tester,
    ) async {
      await pumpApp(tester);
      await openPracticeScreen(tester);
      await tester.tap(find.text('AGL'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      await openPracticeScreen(tester);

      expect(find.text('Wysokość nad ziemią to'), findsNothing);
      expect(find.text('Pytanie z brakiem'), findsOneWidget);
    });

    testWidgets('English with a missing translation shows the Polish note', (
      tester,
    ) async {
      await Hive.box<dynamic>('config').put('questionLanguage', 'en');
      await pumpApp(tester);
      await openPracticeScreen(tester);
      await tester.tap(find.text('AGL'));
      await tester.pumpAndSettle();
      await next(tester);

      expect(find.text('Pytanie z brakiem'), findsOneWidget);
      expect(find.text('Question shown as published by ULC.'), findsOneWidget);
    });
  });

  group('bookmarks and summary', () {
    testWidgets('a bookmark survives a restart of the screen', (tester) async {
      await pumpApp(tester);
      await openPracticeScreen(tester);
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);

      await tester.tap(find.byKey(const Key('practice_bookmark')));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
      await tester.tap(find.byKey(const Key('practice_bookmark')));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
      await tester.tap(find.byKey(const Key('practice_bookmark')));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();
      await openPracticeScreen(tester);
      expect(find.byIcon(Icons.bookmark), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await pumpMode(tester, PracticeMode.bookmarks);
      expect(find.text('Wysokość nad ziemią to'), findsOneWidget);
      expect(find.text('0 / 1'), findsOneWidget);
    });

    testWidgets('the summary offers to repeat the mistakes of the session', (
      tester,
    ) async {
      await pumpApp(tester, premium: true);
      await openPracticeScreen(tester);
      await tester.tap(find.text('AMSL')); // wrong
      await tester.pumpAndSettle();
      await next(tester);
      await tester.tap(find.text('Odpowiedź pierwsza')); // correct
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('practice_finish')));
      await tester.pumpAndSettle();

      expect(find.text('Session summary'), findsOneWidget);
      expect(find.text('1 correct answer'), findsOneWidget);
      expect(find.text('1 wrong answer'), findsOneWidget);

      await tester.tap(find.byKey(const Key('summary_repeat')));
      await tester.pumpAndSettle();

      expect(find.text('REPEAT MISTAKES'), findsOneWidget);
      expect(find.text('Wysokość nad ziemią to'), findsOneWidget);
      expect(find.text('1 / 1'), findsNothing);
      await tester.tap(find.text('AGL'));
      await tester.pumpAndSettle();
      expect(find.text('1 / 1'), findsOneWidget);
      final p = (await repo.progressOf(Licence.ppla, 'PL010-0001'))!;
      expect(p.wrong, 1);
      expect(p.correct, 1);
    });

    testWidgets('finishing the last question shows the summary', (
      tester,
    ) async {
      await pumpApp(tester, mode: PracticeMode.bookmarks);
      await repo.toggleBookmark(Licence.ppla, 'PL010-0001');
      await openPracticeScreen(tester);
      await tester.tap(find.text('AGL'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();

      expect(find.text('Session summary'), findsOneWidget);
      expect(find.byKey(const Key('summary_repeat')), findsNothing);
    });
  });

  group('access', () {
    Future<void> seedToday(int count) async {
      for (var i = 0; i < count; i++) {
        await repo.recordAnswer(Licence.ppla, 'old$i', true, _now);
      }
    }

    testWidgets('a free user may give the 20th answer of the day', (
      tester,
    ) async {
      await seedToday(19);
      await pumpApp(tester);
      await openPracticeScreen(tester);

      await tester.tap(find.text('AGL'));
      await tester.pumpAndSettle();

      expect(paywalls, isEmpty);
      expect((await repo.dailyStat(_now)).answered, 20);
    });

    testWidgets('the 21st answer of a free user opens the paywall and is not '
        'stored', (tester) async {
      await seedToday(20);
      await pumpApp(tester);
      await openPracticeScreen(tester);

      await tester.tap(find.text('AGL'));
      await tester.pumpAndSettle();

      expect(paywalls, [PaywallTrigger.dailyLimit]);
      expect(find.byKey(const Key('practice_limit')), findsOneWidget);
      expect(await repo.progressOf(Licence.ppla, 'PL010-0001'), isNull);
      expect((await repo.dailyStat(_now)).answered, 20);

      // The explicit button opens the paywall again.
      await tester.tap(find.byKey(const Key('practice_limit_premium')));
      await tester.pump();
      expect(paywalls, [PaywallTrigger.dailyLimit, PaywallTrigger.dailyLimit]);
    });

    testWidgets('yesterday\'s answers do not count against today', (
      tester,
    ) async {
      for (var i = 0; i < 20; i++) {
        await repo.recordAnswer(
          Licence.ppla,
          'old$i',
          true,
          DateTime(2026, 4, 30, 23, 59),
        );
      }
      await pumpApp(tester);
      await openPracticeScreen(tester);
      await tester.tap(find.text('AGL'));
      await tester.pumpAndSettle();

      expect(paywalls, isEmpty);
      expect((await repo.dailyStat(_now)).answered, 1);
    });

    testWidgets('a premium user is not limited', (tester) async {
      await seedToday(25);
      await pumpApp(tester, premium: true);
      await openPracticeScreen(tester);

      await tester.tap(find.text('AGL'));
      await tester.pumpAndSettle();

      expect(paywalls, isEmpty);
      expect((await repo.dailyStat(_now)).answered, 26);
    });

    testWidgets('review shows only questions that are due now', (tester) async {
      // Answered three days ago: due one day ago. Answered now: due in 2 days.
      await repo.recordAnswer(
        Licence.ppla,
        'PL010-0002',
        true,
        _now.subtract(const Duration(days: 3)),
      );
      await repo.recordAnswer(Licence.ppla, 'PL010-0001', true, _now);
      await pumpApp(tester, mode: PracticeMode.review, premium: true);
      await openPracticeScreen(tester);

      expect(find.text('Pytanie z brakiem'), findsOneWidget);
      expect(find.text('Wysokość nad ziemią to'), findsNothing);
      expect(find.text('0 / 1'), findsOneWidget);
    });

    testWidgets('an empty mode says so', (tester) async {
      await pumpApp(tester, mode: PracticeMode.review, premium: true);
      await openPracticeScreen(tester);
      expect(find.text('Nothing is due for review today.'), findsOneWidget);
    });

    testWidgets('mistakes and review are locked for a free user', (
      tester,
    ) async {
      await pumpApp(tester, mode: PracticeMode.mistakes);
      await openPracticeScreen(tester);

      expect(find.text('Premium feature'), findsOneWidget);
      expect(find.text('Wysokość nad ziemią to'), findsNothing);
      await tester.tap(find.text('Go Premium!'));
      await tester.pump();
      expect(paywalls, [PaywallTrigger.lockedFeature]);
    });

    testWidgets('subject tiles show counters; locked tiles open the paywall', (
      tester,
    ) async {
      await repo.recordAnswer(Licence.ppla, 'PL010-0001', false, _now);
      await repo.toggleBookmark(Licence.ppla, 'PL010-0002');
      await pumpApp(
        tester,
        home: Scaffold(
          body: SingleChildScrollView(child: QuizList(subject: subjectInfo())),
        ),
      );

      expect(find.text('3 questions not seen yet'), findsOneWidget);
      expect(find.text('1 question to fix'), findsOneWidget);
      expect(find.text('Nothing due'), findsOneWidget);
      expect(find.text('1 bookmarked question'), findsOneWidget);
      expect(find.text('Premium'), findsNWidgets(2));

      await tester.ensureVisible(find.byKey(const Key('mode_mistakes')));
      await tester.tap(find.byKey(const Key('mode_mistakes')));
      await tester.pump();
      expect(paywalls, [PaywallTrigger.lockedFeature]);
      await tester.ensureVisible(find.byKey(const Key('mode_review')));
      await tester.tap(find.byKey(const Key('mode_review')));
      await tester.pump();
      expect(paywalls, hasLength(2));
    });
  });
}

/// Rebuilds the host with a given mode (used to look at another mode after the
/// first screen was closed).
Future<void> pumpMode(WidgetTester tester, PracticeMode mode) async {
  _hostKey.currentState!.setMode(mode);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('open_practice')));
  await tester.pumpAndSettle();
}

final _hostKey = GlobalKey<_HostState>();

class _Host extends StatefulWidget {
  _Host({required this.mode, required this.args, this.home})
    : super(key: _hostKey);

  final PracticeMode mode;
  final PracticeArgs Function(PracticeMode) args;
  final Widget? home;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late PracticeMode mode = widget.mode;
  bool dark = false;

  void setMode(PracticeMode value) => setState(() => mode = value);

  void toggleTheme() => setState(() => dark = !dark);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: dark ? ThemeData.dark() : ThemeData.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home:
          widget.home ??
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open_practice'),
                  onPressed: () => openPractice(context, widget.args(mode)),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
    );
  }
}
