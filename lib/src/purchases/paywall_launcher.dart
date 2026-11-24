import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/progress/providers.dart';
import 'package:pilotiq/src/purchases/paywall_screen.dart';

/// Why the paywall is being opened.
enum PaywallTrigger {
  dailyLimit,
  examLimit,
  examResults,
  lockedFeature,
  profile,
}

extension PaywallTriggerRules on PaywallTrigger {
  /// Opened by the app itself when the user hits a limit. These wait until
  /// the user has answered [paywallMinAnswers] questions in total. The other
  /// triggers are an explicit action (profile, a locked feature, the result
  /// teaser) and always open the paywall.
  bool get isAutomatic =>
      this == PaywallTrigger.dailyLimit || this == PaywallTrigger.examLimit;
}

/// Answers in total (all days, all licences) before an automatic trigger may
/// show the paywall.
const int paywallMinAnswers = 10;

/// Function that actually shows the paywall; overridden in tests.
typedef PaywallOpener = Future<void> Function(
  BuildContext context,
  PaywallTrigger trigger,
);

/// Number of answers given so far, learning and exam simulations together.
Future<int> _totalAnswers(Ref ref) async {
  final stats = await ref.read(progressRepositoryProvider).dailyStats();
  return stats.fold<int>(0, (sum, s) => sum + s.activity);
}

/// Where paywall events are logged: `debugPrint` (there is no analytics SDK).
/// Tests replace it.
final paywallLogProvider = Provider<void Function(String message)>(
  (ref) =>
      (message) => debugPrint(message),
);

/// Only one paywall is open at a time.
class _PaywallGate {
  bool open = false;
}

final _paywallGateProvider = Provider<_PaywallGate>((ref) => _PaywallGate());

/// The real opener: logs the trigger, applies the "not too early" rule to
/// automatic triggers and pushes [PaywallScreen].
final paywallOpenerProvider = Provider<PaywallOpener>((ref) {
  return (context, trigger) async {
    final log = ref.read(paywallLogProvider);
    log('paywall: trigger ${trigger.name}');
    final gate = ref.read(_paywallGateProvider);
    if (gate.open) return;
    if (trigger.isAutomatic) {
      var answers = 0;
      try {
        answers = await _totalAnswers(ref);
      } on Object catch (e) {
        log('paywall: the answer count is unknown ($e); not shown');
        return;
      }
      if (answers < paywallMinAnswers) {
        log(
          'paywall: ${trigger.name} not shown yet ($answers of '
          '$paywallMinAnswers answers)',
        );
        return;
      }
      if (!context.mounted || gate.open) return;
    }
    gate.open = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => PaywallScreen(trigger: trigger),
        ),
      );
    } finally {
      gate.open = false;
    }
  };
});

/// The single entry point for showing the paywall.
Future<void> openPaywall(
  BuildContext context, {
  required PaywallTrigger trigger,
}) {
  final container = ProviderScope.containerOf(context, listen: false);
  return container.read(paywallOpenerProvider)(context, trigger);
}
