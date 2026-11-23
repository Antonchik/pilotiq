import 'package:flutter/material.dart';
import 'package:pilotiq/src/bank/bank_text.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';

/// How an answer option is drawn.
enum AnswerTileState {
  /// Not chosen; still tappable until the question is answered.
  idle,

  /// The correct answer, shown after the question was answered.
  correct,

  /// The answer the user chose and that was wrong.
  wrong,
}

/// One answer option of a practice question. Colour is never the only signal:
/// the icon and the accessibility label tell the state as well.
class AnswerTile extends StatelessWidget {
  const AnswerTile({
    super.key,
    required this.text,
    required this.state,
    required this.onTap,
  });

  final String text;
  final AnswerTileState state;

  /// `null` once the question was answered.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final (Color? colour, IconData icon) = switch (state) {
      AnswerTileState.idle => (null, Icons.circle_outlined),
      AnswerTileState.correct => (Colors.green.shade600, Icons.check_circle),
      AnswerTileState.wrong => (Colors.red.shade600, Icons.cancel),
    };
    final stateLabel = switch (state) {
      AnswerTileState.idle => '',
      AnswerTileState.correct => ', ${local.practiceAnswerCorrectSemantics}',
      AnswerTileState.wrong => ', ${local.practiceAnswerWrongSemantics}',
    };
    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      onTap: onTap,
      label: '${bankPlainText(text)}$stateLabel',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: colour ?? scheme.outlineVariant,
            width: colour != null ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 22, color: colour),
                const SizedBox(width: 12),
                Expanded(
                  child: BankText(
                    text,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
