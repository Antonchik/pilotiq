import 'package:flutter/material.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';

/// `m:ss`, or `h:mm:ss` from one hour on.
String formatClock(Duration d) {
  final total = d.isNegative ? 0 : d.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
  return '$m:$ss';
}

/// Whole minutes, rounded up (for labels read by a screen reader).
int ceilMinutes(Duration d) => d.isNegative ? 0 : (d.inSeconds + 59) ~/ 60;

/// Local date and time of [d] in the language of the app.
String formatDateTime(BuildContext context, DateTime d) {
  final local = d.toLocal();
  final m = MaterialLocalizations.of(context);
  return '${m.formatShortDate(local)}, '
      '${m.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}

/// Pass / fail badge: icon and text, never colour alone.
class PassBadge extends StatelessWidget {
  const PassBadge({super.key, required this.passed, this.large = false});

  final bool passed;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = passed
        ? (dark ? Colors.green.shade300 : Colors.green.shade800)
        : (dark ? Colors.red.shade300 : Colors.red.shade800);
    final style =
        (large
                ? Theme.of(context).textTheme.headlineSmall
                : Theme.of(context).textTheme.titleSmall)
            ?.copyWith(color: color, fontWeight: FontWeight.bold);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(passed ? Icons.check_circle : Icons.cancel, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            passed ? local.examPassed : local.examFailed,
            style: style,
          ),
        ),
      ],
    );
  }
}
