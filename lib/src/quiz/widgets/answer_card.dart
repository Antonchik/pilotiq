import 'package:flutter/material.dart';
import 'package:pilotiq/src/bank/bank_text.dart';

/// One answer option. [feedback] colours the border (green / red) when the
/// answer is revealed; [selected] only marks the chosen option.
class AnswerCard extends StatelessWidget {
  const AnswerCard({
    super.key,
    required this.text,
    required this.selected,
    required this.onTap,
    this.feedback,
  });

  final String text;
  final bool selected;
  final Color? feedback;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: feedback ?? Theme.of(context).colorScheme.outlineVariant,
          width: feedback != null ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                size: 20,
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(left: 12),
                  child: BankText(
                    text,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
