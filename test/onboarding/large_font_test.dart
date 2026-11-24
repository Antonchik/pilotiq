import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pilotiq/src/app.dart';
import 'package:pilotiq/src/domain/catalog.dart';
import 'package:pilotiq/src/home/home.dart';
import 'package:pilotiq/src/notifications/fake_notification_service.dart';
import 'package:pilotiq/src/notifications/notification_service.dart';
import 'package:pilotiq/src/notifications/providers.dart';
import 'package:pilotiq/src/progress/exam_attempt.dart';

import '../bank/fake_bank.dart';
import '../dashboard/dashboard_helpers.dart';

/// Every screen of the app that can be reached without a purchase (the study
/// screens of the practice and exam steps are covered by their own steps), with
/// large system fonts on small screens, in both languages.
///
/// For each screen: nothing overflows or asserts (an exception fails the
/// test), and every action can be scrolled to, lies inside the visible area
/// (not under the bottom bar) and can be tapped.
///
/// The only tolerated overflow is inside the standard Material date picker at
/// the largest font scale (it is a framework dialog, not ours).
///
/// Note: the test font draws every character as a full-em square, which is
/// wider than real fonts, so this is a stricter layout than on a device.
void main() {
  AppHarness.registerSetUp();

  const sizes = [Size(320, 640), Size(360, 740), Size(411, 800)];
  const scales = [1.3, 1.5, 2.0, 3.0];
  const languages = ['en', 'pl'];

  void configure(WidgetTester tester, String lang, double scale, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    tester.platformDispatcher.localesTestValue = [Locale(lang)];
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearAllTestValues();
    });
  }

  /// Runs [body] (which opens and closes the standard date picker); layout
  /// overflows reported meanwhile are tolerated at scale 3.0 only.
  Future<void> withDatePicker(
    double scale,
    Future<void> Function() body,
  ) async {
    final previous = FlutterError.onError;
    if (scale >= 3.0) {
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) {
          return;
        }
        previous?.call(details);
      };
    }
    try {
      await body();
    } finally {
      FlutterError.onError = previous;
    }
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isNotEmpty) return;
    final scrollables = find.byType(Scrollable);
    if (scrollables.evaluate().isEmpty) return;
    final list = scrollables.last;
    for (final delta in [300.0, -300.0]) {
      for (var i = 0; i < 60 && finder.evaluate().isEmpty; i++) {
        await tester.drag(list, Offset(0, delta));
        await tester.pump();
      }
      if (finder.evaluate().isNotEmpty) return;
    }
  }

  /// Scrolls to [finder], checks that it is fully visible and not covered by
  /// the bottom bar, and optionally taps it.
  Future<void> reach(
    WidgetTester tester,
    Finder finder, {
    bool tap = true,
  }) async {
    await scrollTo(tester, finder);
    expect(finder, findsOneWidget, reason: 'not found: $finder');
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    final rect = tester.getRect(finder);
    final screen = tester.view.physicalSize;
    var bottom = screen.height;
    final nav = find.byType(NavigationBar).hitTestable();
    final inNav = find
        .descendant(of: find.byType(NavigationBar), matching: finder)
        .evaluate()
        .isNotEmpty;
    if (nav.evaluate().isNotEmpty && !inNav) bottom = tester.getTopLeft(nav).dy;
    expect(rect.left, greaterThanOrEqualTo(0), reason: '$finder');
    expect(rect.right, lessThanOrEqualTo(screen.width), reason: '$finder');
    expect(rect.top, greaterThanOrEqualTo(0), reason: '$finder');
    // A tile taller than the visible area is aligned to the top of the list;
    // it must show at least as much as a finger needs (48 px) or all of it.
    final visible = rect.intersect(Rect.fromLTWH(0, 0, screen.width, bottom));
    expect(
      visible.height,
      greaterThanOrEqualTo(rect.height < 48 ? rect.height : 48),
      reason: 'hidden: $finder',
    );
    if (!tap) return;
    if (rect.bottom <= bottom) {
      await tester.tap(finder);
    } else {
      await tester.tapAt(visible.center);
    }
    await tester.pumpAndSettle();
  }

  Future<void> pumpApp(WidgetTester tester, AppHarness h) async {
    await tester.pumpWidget(
      ProviderScope(overrides: h.overrides, child: const MyApp()),
    );
    await tester.pumpAndSettle();
  }

  /// The app with the reminders switched on over a fake notification service.
  Future<void> pumpReminderApp(
    WidgetTester tester,
    AppHarness h,
    FakeNotificationService service,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...h.overrides,
          remindersSupportedProvider.overrideWithValue(true),
          notificationServiceProvider.overrideWithValue(service),
          reminderPrefsProvider.overrideWithValue(MemoryReminderPrefsStore()),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pickDate(
    WidgetTester tester,
    double scale,
    Finder opener,
  ) async {
    await withDatePicker(scale, () async {
      await reach(tester, opener);
      await reach(tester, find.text('OK'));
    });
  }

  /// Opens the standard time picker through [opener] and confirms it; layout
  /// overflows of the framework dialog are tolerated at scale 3.0 only.
  Future<void> pickTime(WidgetTester tester, double scale, Finder opener) =>
      pickDate(tester, scale, opener);

  for (final lang in languages) {
    for (final scale in scales) {
      for (final size in sizes) {
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

        // --- start-up -------------------------------------------------
        screen('start-up: loading screen', (tester) async {
          final never = Completer<ProviderContainer>();
          await tester.pumpWidget(PilotiqRoot(initialize: () => never.future));
          await tester.pump();
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
        });

        screen('start-up: error screen and retry', (tester) async {
          var calls = 0;
          await tester.pumpWidget(
            PilotiqRoot(
              initialize: () async {
                calls++;
                throw StateError('x');
              },
            ),
          );
          await tester.pumpAndSettle();
          await reach(tester, find.byKey(const Key('startup_retry')));
          expect(calls, 2);
        });

        screen('start-up: synchronous failure is shown, not thrown', (
          tester,
        ) async {
          await tester.pumpWidget(
            PilotiqRoot(initialize: () => throw StateError('sync')),
          );
          await tester.pumpAndSettle();
          await reach(
            tester,
            find.byKey(const Key('startup_retry')),
            tap: false,
          );
        });

        // --- onboarding ----------------------------------------------
        screen('onboarding: full path with date and goal', (tester) async {
          final h = AppHarness();
          await pumpApp(tester, h);
          await reach(tester, find.byKey(const Key('onboarding_licence_pplh')));
          await reach(tester, find.byKey(const Key('onboarding_language')));
          await reach(tester, find.text('English'));
          await reach(tester, find.byKey(const Key('onboarding_next')));
          await pickDate(
            tester,
            scale,
            find.byKey(const Key('onboarding_exam_date')),
          );
          await reach(tester, find.byKey(const Key('onboarding_back')));
          await reach(tester, find.byKey(const Key('onboarding_next')));
          await reach(tester, find.byKey(const Key('onboarding_skip')));
          await reach(tester, find.byKey(const Key('onboarding_goal_10')));
          await reach(tester, find.byKey(const Key('onboarding_goal_20')));
          await reach(tester, find.byKey(const Key('onboarding_goal_40')));
          await reach(tester, find.byKey(const Key('onboarding_finish')));
          expect(find.byType(HomeScreen), findsOneWidget);
          expect(Hive.box<dynamic>('config').get('onboardingDone'), true);
        });

        screen('onboarding: SPL, skipped date, default goal', (tester) async {
          final h = AppHarness();
          await pumpApp(tester, h);
          await reach(tester, find.byKey(const Key('onboarding_licence_spl')));
          await reach(tester, find.byKey(const Key('onboarding_next')));
          await reach(tester, find.byKey(const Key('onboarding_skip')));
          await reach(tester, find.byKey(const Key('onboarding_finish')));
          expect(find.byType(HomeScreen), findsOneWidget);
        });

        screen('onboarding: upgrading user with the banner', (tester) async {
          final h = AppHarness();
          await h.repository.saveAttempt(
            ExamAttempt(
              id: 'legacy_x',
              licence: Licence.pplh,
              subject: SubjectId.meteorology,
              startedAt: DateTime.utc(1970),
              finishedAt: DateTime.utc(1970),
              durationSec: 0,
              total: 0,
              correct: 0,
              passed: false,
              reason: AttemptReason.legacy,
            ),
          );
          await pumpApp(tester, h);
          await reach(
            tester,
            find.byKey(const Key('onboarding_legacy_banner')),
            tap: false,
          );
          await reach(tester, find.byKey(const Key('onboarding_next')));
          await reach(tester, find.byKey(const Key('onboarding_next')));
          await reach(tester, find.byKey(const Key('onboarding_finish')));
          expect(find.byType(HomeScreen), findsOneWidget);
        });

        // --- tab "Today" ----------------------------------------------
        screen('today: all cards (premium, with data)', (tester) async {
          final h = AppHarness(premium: true);
          await h.seedConfig({'examDate': '2026-12-03'});
          for (var i = 0; i < 12; i++) {
            await h.repository.recordAnswer(
              Licence.ppla,
              'PL010-000${1 + i % 4}',
              i % 3 == 0,
              testNow,
            );
          }
          for (final a in [
            ExamAttempt(
              id: 'real',
              licence: Licence.ppla,
              subject: SubjectId.airLaw,
              startedAt: DateTime(2026, 11, 20, 10),
              finishedAt: DateTime(2026, 11, 20, 10, 40),
              durationSec: 2400,
              total: 12,
              correct: 9,
              passed: true,
              reason: AttemptReason.finished,
            ),
            ExamAttempt(
              id: 'legacy',
              licence: Licence.ppla,
              subject: SubjectId.airLaw,
              startedAt: DateTime.utc(1970),
              finishedAt: DateTime.utc(1970),
              durationSec: 0,
              total: 0,
              correct: 0,
              passed: true,
              reason: AttemptReason.legacy,
            ),
          ]) {
            await h.repository.saveAttempt(a);
          }
          await pumpApp(tester, h);
          for (final key in [
            'dashboard_exam',
            'dashboard_goal',
            'dashboard_streak',
            'dashboard_overview',
            'dashboard_readiness',
            'readiness_air_law',
            'readiness_meteorology',
            'dashboard_weak',
            'dashboard_last_exam',
          ]) {
            await reach(tester, find.byKey(Key(key)), tap: false);
          }
          await reach(tester, find.byKey(const Key('dashboard_due')));
          expect(find.byType(HomeScreen), findsOneWidget);
        });

        screen('today: free, no exam date', (tester) async {
          final h = AppHarness();
          await h.seedConfig();
          await pumpApp(tester, h);
          await reach(
            tester,
            find.byKey(const Key('dashboard_exam')),
            tap: false,
          );
          await reach(
            tester,
            find.byKey(const Key('dashboard_exam_set')),
            tap: false,
          );
          await reach(
            tester,
            find.byKey(const Key('dashboard_readiness_locked')),
          );
          await reach(tester, find.byKey(const Key('dashboard_due')));
          await reach(
            tester,
            find.byKey(const Key('dashboard_last_exam')),
            tap: false,
          );
          expect(h.paywalls, isNotEmpty);
        });

        screen('today: past exam date opens the picker', (tester) async {
          final h = AppHarness();
          await h.seedConfig({'examDate': '2026-11-20'});
          await pumpApp(tester, h);
          await pickDate(
            tester,
            scale,
            find.byKey(const Key('dashboard_exam_set')),
          );
        });

        screen('today: bank load error and retry', (tester) async {
          final bundle = FakeBankBundle()
            ..failures['assets/data/bank_ppla.json'] = 20;
          final h = AppHarness(bank: fakeBankRepository(bundle));
          await h.seedConfig();
          await pumpApp(tester, h);
          expect(find.byKey(const Key('dashboard_retry')), findsOneWidget);
          await reach(tester, find.byKey(const Key('dashboard_retry')));
        });

        // --- tab "Subjects" -------------------------------------------
        screen('subjects: list, source note and the subject screen', (
          tester,
        ) async {
          final h = AppHarness();
          await h.seedConfig();
          await pumpApp(tester, h);
          await reach(tester, find.byKey(const Key('tab_subjects')));
          await reach(
            tester,
            find.byKey(const Key('question_language')),
            tap: false,
          );
          await reach(
            tester,
            find.byKey(const Key('subject_meteorology')),
            tap: false,
          );
          await reach(tester, find.textContaining('01.08.2024'), tap: false);
          await reach(tester, find.byKey(const Key('subject_air_law')));
          for (final key in [
            'mode_learn',
            'mode_exam',
            'mode_mistakes',
            'mode_review',
            'mode_bookmarks',
          ]) {
            await reach(tester, find.byKey(Key(key)), tap: false);
          }
          await reach(tester, find.byType(BackButton));
        });

        screen('subjects: bank load error and retry', (tester) async {
          final bundle = FakeBankBundle()
            ..failures['assets/data/bank_ppla.json'] = 20;
          final h = AppHarness(bank: fakeBankRepository(bundle));
          await h.seedConfig();
          await pumpApp(tester, h);
          await reach(tester, find.byKey(const Key('tab_subjects')));
          await reach(tester, find.byType(OutlinedButton));
        });

        // --- tab "Profile", its dialogs and About ------------------------
        screen('profile: every setting and dialog', (tester) async {
          final h = AppHarness();
          await h.seedConfig({'examDate': '2026-12-03'});
          await pumpApp(tester, h);
          await reach(tester, find.byKey(const Key('tab_profile')));
          await reach(tester, find.byKey(const Key('settings_premium')));
          expect(h.paywalls, isNotEmpty);

          await reach(tester, find.byKey(const Key('settings_licence')));
          for (final l in ['ppla', 'pplh', 'spl']) {
            await reach(
              tester,
              find.byKey(Key('licence_option_$l')),
              tap: false,
            );
          }
          await reach(tester, find.byKey(const Key('licence_option_pplh')));

          await reach(
            tester,
            find.byKey(const Key('settings_question_language')),
          );
          await reach(tester, find.text('English'));

          await reach(tester, find.byKey(const Key('settings_daily_goal')));
          for (final g in [10, 20]) {
            await reach(tester, find.byKey(Key('goal_option_$g')), tap: false);
          }
          await reach(tester, find.byKey(const Key('goal_option_40')));

          await pickDate(
            tester,
            scale,
            find.byKey(const Key('settings_exam_date')),
          );
          await reach(
            tester,
            find.byKey(const Key('settings_exam_date_clear')),
          );

          await reach(tester, find.byKey(const Key('settings_theme')));
          await reach(tester, find.text(lang == 'pl' ? 'Ciemny' : 'Dark'));

          await reach(tester, find.byKey(const Key('settings_about')));
          expect(find.byKey(const Key('about_disclaimer')), findsOneWidget);
          final config = Hive.box<dynamic>('config');
          expect(config.get('dailyGoal'), 40);
          expect(config.get('licence'), 'pplh');
          expect(config.get('themeMode'), 'dark');
        });

        screen('profile: premium user', (tester) async {
          final h = AppHarness(premium: true);
          await h.seedConfig();
          await pumpApp(tester, h);
          await reach(tester, find.byKey(const Key('tab_profile')));
          await reach(tester, find.byKey(const Key('settings_premium')));
          expect(h.paywalls, isEmpty);
        });

        // --- reminders (S10) -------------------------------------------
        screen('onboarding: reminders page, turn on and change the time', (
          tester,
        ) async {
          final service = FakeNotificationService();
          await pumpReminderApp(tester, AppHarness(), service);
          await reach(tester, find.byKey(const Key('onboarding_next')));
          await reach(tester, find.byKey(const Key('onboarding_skip')));
          await reach(tester, find.byKey(const Key('onboarding_next')));
          await reach(
            tester,
            find.byKey(const Key('onboarding_reminders_enable')),
          );
          await pickTime(
            tester,
            scale,
            find.byKey(const Key('onboarding_reminder_time')),
          );
          await reach(
            tester,
            find.byKey(const Key('onboarding_reminders_off')),
          );
          await reach(
            tester,
            find.byKey(const Key('onboarding_reminders_enable')),
          );
          await reach(tester, find.byKey(const Key('onboarding_back')));
          await reach(tester, find.byKey(const Key('onboarding_next')));
          await reach(tester, find.byKey(const Key('onboarding_finish')));
          expect(find.byType(HomeScreen), findsOneWidget);
          expect(Hive.box<dynamic>('config').get('reminderTime'), '19:00');
        });

        screen('onboarding: reminders page after a refusal', (tester) async {
          final service = FakeNotificationService(
            permission: NotificationPermission.denied,
          );
          await pumpReminderApp(tester, AppHarness(), service);
          await reach(tester, find.byKey(const Key('onboarding_next')));
          await reach(tester, find.byKey(const Key('onboarding_skip')));
          await reach(tester, find.byKey(const Key('onboarding_next')));
          await reach(
            tester,
            find.byKey(const Key('onboarding_reminders_enable')),
          );
          await reach(
            tester,
            find.byKey(const Key('onboarding_reminders_denied')),
            tap: false,
          );
          await reach(
            tester,
            find.byKey(const Key('onboarding_reminders_open_settings')),
          );
          expect(service.openSettingsCount, 1);
          await reach(tester, find.byKey(const Key('onboarding_finish')));
          expect(find.byType(HomeScreen), findsOneWidget);
        });

        screen('profile: reminders section, time dialog and switch', (
          tester,
        ) async {
          final service = FakeNotificationService();
          final h = AppHarness();
          await h.seedConfig({'reminderTime': '07:30'});
          await pumpReminderApp(tester, h, service);
          await reach(tester, find.byKey(const Key('tab_profile')));
          await reach(
            tester,
            find.byKey(const Key('settings_reminders_switch')),
            tap: false,
          );
          await pickTime(
            tester,
            scale,
            find.byKey(const Key('settings_reminder_time')),
          );
          await reach(
            tester,
            find.byKey(const Key('settings_reminders_switch')),
          );
          expect(Hive.box<dynamic>('config').get('reminderTime'), isNull);
          await reach(
            tester,
            find.byKey(const Key('settings_reminders_switch')),
          );
          expect(Hive.box<dynamic>('config').get('reminderTime'), '19:00');
        });

        screen('profile: reminders blocked and failed', (tester) async {
          final blocked = FakeNotificationService(
            permission: NotificationPermission.denied,
          );
          final h = AppHarness();
          await h.seedConfig({'reminderTime': '07:30'});
          await pumpReminderApp(tester, h, blocked);
          await reach(tester, find.byKey(const Key('tab_profile')));
          await reach(
            tester,
            find.byKey(const Key('settings_reminders_blocked')),
            tap: false,
          );
          await reach(
            tester,
            find.byKey(const Key('settings_reminders_open_settings')),
          );
          expect(blocked.openSettingsCount, 1);
        });

        screen('profile: reminders scheduling failed and retry', (
          tester,
        ) async {
          final failing = FakeNotificationService()..failWith = StateError('x');
          final h = AppHarness();
          await h.seedConfig({'reminderTime': '07:30'});
          await pumpReminderApp(tester, h, failing);
          await reach(tester, find.byKey(const Key('tab_profile')));
          await reach(
            tester,
            find.byKey(const Key('settings_reminders_failed')),
            tap: false,
          );
          failing.failWith = null;
          await reach(
            tester,
            find.byKey(const Key('settings_reminders_retry')),
          );
          expect(failing.scheduled, isNotEmpty);
        });

        screen('about: every line and link', (tester) async {
          final h = AppHarness();
          await h.seedConfig();
          await pumpApp(tester, h);
          await reach(tester, find.byKey(const Key('tab_profile')));
          await reach(tester, find.byKey(const Key('settings_about')));
          for (final key in [
            'about_version',
            'about_disclaimer',
            'about_source_ppla',
            'about_source_pplh',
            'about_source_spl',
            'about_source_bpl',
          ]) {
            await reach(tester, find.byKey(Key(key)), tap: false);
          }
          await reach(
            tester,
            find.text(lang == 'pl' ? 'Regulamin' : 'Terms of Service'),
            tap: false,
          );
          await reach(
            tester,
            find.text(lang == 'pl' ? 'Polityka Prywatności' : 'Privacy Policy'),
            tap: false,
          );
        });
      }
    }
  }
}
