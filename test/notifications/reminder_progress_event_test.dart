import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pilotiq/src/bank/question_bank_repository.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/notifications/fake_notification_service.dart';
import 'package:pilotiq/src/notifications/providers.dart';
import 'package:pilotiq/src/progress/providers.dart';
import 'package:pilotiq/src/purchases/fake_purchase_service.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';
import 'package:pilotiq/src/quiz/practice/practice_controller.dart';
import 'package:pilotiq/src/quiz/practice/practice_session.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../bank/fake_bank.dart';
import '../bank/memory_hive.dart';

/// Polish C1: the reminders follow the answers by event, no timer.
void main() {
  setUpAll(tzdata.initializeTimeZones);
  tearDown(() async => Hive.close());

  test('the 20th answer removes today\'s reminder without any timer', () async {
    final service = FakeNotificationService();
    await service.initialize();
    final repository = memoryProgressRepository();
    final box = await openMemoryBox('config');
    await box.put('onboardingDone', true);
    await box.put('reminderTime', '19:00');
    final now = tz.TZDateTime(
      tz.getLocation('Europe/Warsaw'),
      2026,
      11,
      23,
      10,
    );
    final questions = parseBank(
      fakeBankJson(Licence.ppla),
      licence: Licence.ppla,
    ).questionsOf(SubjectId.airLaw);

    final container = ProviderContainer(
      overrides: [
        progressRepositoryProvider.overrideWithValue(repository),
        notificationServiceProvider.overrideWithValue(service),
        reminderPrefsProvider.overrideWithValue(MemoryReminderPrefsStore()),
        clockProvider.overrideWithValue(Clock(() => now)),
        purchaseServiceProvider.overrideWithValue(FakePurchaseService()),
        questionBankRepositoryProvider.overrideWithValue(fakeBankRepository()),
      ],
    );
    addTearDown(container.dispose);
    container.read(reminderCoordinatorProvider);
    await container.read(userSettingsProvider.future);
    await container
        .read(reminderCoordinatorProvider.notifier)
        .reschedule(force: true);
    expect(service.scheduledSorted.first.at.day, 23);

    for (var i = 0; i < 19; i++) {
      await repository.recordAnswer(Licence.ppla, 'old$i', true, now);
    }
    final provider =
        AsyncNotifierProvider.autoDispose<PracticeController, PracticeState>(
          () => PracticeController(
            PracticeArgs(
              licence: Licence.ppla,
              subject: SubjectId.airLaw,
              mode: PracticeMode.learn,
              questions: questions,
            ),
          ),
        );
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);
    await container.read(provider.future);

    await container.read(provider.notifier).answer(0);
    // Let the event-driven check (box read + reschedule) finish; no timer.
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    expect((await repository.dailyStat(now)).answered, 20);
    expect(service.scheduledSorted.first.at.day, 24);
  });
}
