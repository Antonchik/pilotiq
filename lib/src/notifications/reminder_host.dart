import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/notifications/providers.dart';

/// Rebuilds the reminder schedule when the app starts, goes to the background
/// (the daily goal may just have been reached), comes back (a new day, the
/// permission may have changed) and when the device language changes.
class ReminderLifecycleHost extends ConsumerStatefulWidget {
  const ReminderLifecycleHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ReminderLifecycleHost> createState() =>
      _ReminderLifecycleHostState();
}

class _ReminderLifecycleHostState extends ConsumerState<ReminderLifecycleHost>
    with WidgetsBindingObserver {
  /// How often the daily progress is looked at while the app is open.
  static const Duration _progressCheck = Duration(seconds: 15);

  Timer? _timer;

  void _startTimer() {
    _timer ??= Timer.periodic(
      _progressCheck,
      (_) => unawaited(
        ref.read(reminderCoordinatorProvider.notifier).checkProgress(),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
    // After the first frame, so that the start-up of the app is not delayed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reschedule(force: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _reschedule({bool force = false}) => unawaited(
    ref.read(reminderCoordinatorProvider.notifier).reschedule(force: force),
  );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _startTimer();
    if (state == AppLifecycleState.paused) {
      _timer?.cancel();
      _timer = null;
    }
    if (state == AppLifecycleState.resumed ||
        state == AppLifecycleState.paused) {
      _reschedule();
    }
  }

  @override
  void didChangeLocales(List<Locale>? locales) => _reschedule(force: true);

  @override
  Widget build(BuildContext context) => widget.child;
}
