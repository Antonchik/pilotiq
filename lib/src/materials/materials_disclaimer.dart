import 'package:flutter/material.dart';
import 'package:pilotiq/src/bank/bank_source.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';

/// "Materiały nie zastępują szkolenia w ATO/DTO ani aktualnych przepisów",
/// optionally with "Stan prawny na `<date>`" and the "Polish only" note.
class MaterialsDisclaimer extends StatelessWidget {
  const MaterialsDisclaimer({
    super.key,
    this.legalStateAsOf,
    this.compact = false,
    this.polishOnlyNote = false,
  });

  final DateTime? legalStateAsOf;

  /// One small line (under an explanation) instead of a highlighted block.
  final bool compact;

  /// Add the note that the materials are only in Polish.
  final bool polishOnlyNote;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final date = legalStateAsOf;
    final lines = [
      local.materialsDisclaimer,
      if (date != null) local.materialsLegalState(formatBankDate(date)),
      if (polishOnlyNote) local.materialsPolishOnly,
    ];
    if (compact) {
      return Text(
        lines.join(' '),
        key: const Key('materials_disclaimer'),
        style: theme.textTheme.bodySmall,
      );
    }
    final scheme = theme.colorScheme;
    return Container(
      key: const Key('materials_disclaimer'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in lines)
                  Text(
                    line,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
