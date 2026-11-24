import 'dart:convert';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pilotiq/src/bank/models.dart';
import 'package:pilotiq/src/bank/question_bank_repository.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/exam_sim/exam_controller.dart';
import 'package:pilotiq/src/exam_sim/exam_entry.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/progress/exam_attempt.dart';
import 'package:pilotiq/src/progress/progress_repository.dart';
import 'package:pilotiq/src/progress/providers.dart';
import 'package:pilotiq/src/progress/question_progress.dart';
import 'package:pilotiq/src/purchases/fake_purchase_service.dart';
import 'package:pilotiq/src/purchases/paywall_launcher.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';

import '../bank/memory_hive.dart';

/// A bank of [count] communications questions (PL090-0001...), every one with
/// the correct answer "ok N" and the wrong ones "bad1 N" ... "bad3 N".
String examBankJson(Licence licence, {int count = 14}) => jsonEncode({
  'schema': 2,
  'licence': licence.id,
  'source': {
    'file': 'x.pdf',
    'sha256': '00',
    'date': '2024-07-26',
    'kind': 'pdf',
  },
  'questions': [
    for (var n = 1; n <= count; n++)
      {
        'id': 'PL090-${n.toString().padLeft(4, '0')}',
        'number': 'PL090-${n.toString().padLeft(4, '0')}',
        'topic': 'PL090',
        'subject': 'communications',
        'q': {'pl': 'Pytanie $n', 'en': 'Question text $n'},
        'a': [
          {'pl': 'ok $n', 'en': 'ok $n'},
          for (var k = 1; k <= 3; k++) {'pl': 'bad$k $n', 'en': 'bad$k $n'},
        ],
        'correct': 0,
      },
  ],
});

List<Question> examQuestions({int count = 14}) => parseBank(
  examBankJson(Licence.ppla, count: count),
  licence: Licence.ppla,
).questionsOf(SubjectId.communications);

ExamArgs examArgs(List<Question> questions) => ExamArgs(
  licence: Licence.ppla,
  subject: SubjectId.communications,
  spec: ExamSpec.forSubject(SubjectId.communications, licence: Licence.ppla),
  questions: questions,
);

/// A repository whose first writes of the given kinds throw.
class FlakyRepository extends ProgressRepository {
  FlakyRepository() : super(openBox: openMemoryBox);

  int failAttemptSaves = 0;
  int failInProgressSaves = 0;
  int attemptSaves = 0;
  int recorded = 0;

  @override
  Future<void> saveAttempt(ExamAttempt attempt) {
    if (failAttemptSaves > 0) {
      failAttemptSaves--;
      throw StateError('disk full');
    }
    attemptSaves++;
    return super.saveAttempt(attempt);
  }

  @override
  Future<void> saveInProgressAttempt(InProgressAttempt attempt) {
    if (failInProgressSaves > 0) {
      failInProgressSaves--;
      throw StateError('disk full');
    }
    return super.saveInProgressAttempt(attempt);
  }

  @override
  Future<QuestionProgress> recordAnswer(
    Licence licence,
    String qid,
    bool correct,
    DateTime now,
  ) {
    recorded++;
    return super.recordAnswer(licence, qid, correct, now);
  }
}

/// Everything an exam test needs: memory boxes, a fake clock and Premium
/// switch, a paywall recorder and a host app with a button that opens the
/// exam.
class ExamHarness {
  ExamHarness({ProgressRepository? repository})
    : repo = repository ?? memoryProgressRepository();

  ProgressRepository repo;
  final List<PaywallTrigger> paywalls = [];
  DateTime now = DateTime(2026, 5, 1, 12);
  late FakePurchaseService service;
  late List<Question> questions = examQuestions();
  SubjectId subject = SubjectId.communications;

  Future<void> setUp() async {
    await openMemoryBox('config');
  }

  Future<void> tearDown() => Hive.close();

  ExamArgs get args => ExamArgs(
    licence: Licence.ppla,
    subject: subject,
    spec: ExamSpec.forSubject(subject, licence: Licence.ppla),
    questions: questions,
  );

  Future<void> pump(
    WidgetTester tester, {
    bool premium = false,
    Locale locale = const Locale('en'),
    Size size = const Size(1080, 2400),
    double scale = 1,
    Widget? home,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // A new tree: nothing of a previous host (routes) is kept.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          purchaseServiceProvider.overrideWithValue(
            service = FakePurchaseService(premium: premium),
          ),
          progressRepositoryProvider.overrideWithValue(repo),
          questionBankRepositoryProvider.overrideWithValue(
            QuestionBankRepository(
              bundle: ExamBankBundle(),
              parser: (json, licence) async =>
                  parseBank(json, licence: licence),
            ),
          ),
          clockProvider.overrideWithValue(Clock(() => now)),
          randomProvider.overrideWithValue(Random(7)),
          paywallOpenerProvider.overrideWithValue((context, trigger) async {
            paywalls.add(trigger);
          }),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home:
              home ??
              Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      key: const Key('open_exam'),
                      onPressed: () => openExamSimulation(context, args),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('open_exam')));
    await settle(tester);
  }

  Future<void> start(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('exam_start')));
    await settle(tester);
  }

  /// Advances the fake clock and lets the exam's timer notice it.
  Future<void> advance(WidgetTester tester, Duration d) async {
    now = now.add(d);
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
  }

  Future<List<ExamAttempt>> attempts() =>
      repo.attempts(Licence.ppla, subject: subject);

  Future<InProgressAttempt?> unfinished() =>
      repo.loadInProgressAttempt(Licence.ppla, subject);

  /// An old finished attempt of this version (counts against the free limit).
  Future<void> seedAttempt({
    String id = 'old',
    AttemptReason reason = AttemptReason.finished,
    int correct = 10,
    int total = 12,
    DateTime? startedAt,
  }) {
    final t = startedAt ?? DateTime(2026, 4, 1, 10);
    return repo.saveAttempt(
      ExamAttempt(
        id: id,
        licence: Licence.ppla,
        subject: subject,
        startedAt: t,
        finishedAt: t.add(const Duration(minutes: 20)),
        durationSec: 1200,
        total: total,
        correct: correct,
        passed: correct / total >= 0.75,
        reason: reason,
      ),
    );
  }
}

/// Lets timers and the (in-memory) storage finish their work.
Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

/// Serves [examBankJson] for every licence.
class ExamBankBundle extends AssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      examBankJson(
        Licence.values.firstWhere((l) => key.endsWith(l.bankFileName)),
      );

  @override
  Future<ByteData> load(String key) async {
    final bytes = Uint8List.fromList(utf8.encode(await loadString(key)));
    return ByteData.sublistView(bytes);
  }
}
