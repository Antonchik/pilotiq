import 'package:flutter/material.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';

/// Overview of the questions of an exam: answered, not answered and marked.
/// State is told by icons and borders as well as by colour. It owns no state
/// (it is shown in a sheet that lives outside the exam's provider scope).
class QuestionGrid extends StatelessWidget {
  const QuestionGrid({
    super.key,
    required this.count,
    required this.currentIndex,
    required this.isAnswered,
    required this.isFlagged,
    required this.onSelect,
  });

  final int count;
  final int currentIndex;
  final bool Function(int index) isAnswered;
  final bool Function(int index) isFlagged;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _Legend(Icons.check_circle, local.examGridLegendAnswered),
              _Legend(Icons.circle_outlined, local.examGridLegendUnanswered),
              _Legend(Icons.flag, local.examGridLegendFlagged),
            ],
          ),
        ),
        Flexible(
          child: GridView.builder(
            key: const Key('exam_grid'),
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 72 * scale,
              mainAxisExtent: 64 * scale,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: count,
            itemBuilder: (context, i) {
              final answered = isAnswered(i);
              final flagged = isFlagged(i);
              final current = i == currentIndex;
              final states = [
                if (current) local.examGridStateCurrent,
                answered
                    ? local.examGridStateAnswered
                    : local.examGridStateUnanswered,
                if (flagged) local.examGridStateFlagged,
              ];
              return Semantics(
                button: true,
                selected: current,
                excludeSemantics: true,
                label:
                    '${local.examGridCell(i + 1)}, ${states.join(', ')}',
                onTap: () => onSelect(i),
                child: InkWell(
                  key: Key('grid_cell_$i'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onSelect(i),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: answered ? scheme.primaryContainer : null,
                      border: Border.all(
                        color: current ? scheme.primary : scheme.outline,
                        width: current ? 3 : 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${i + 1}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: current
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                answered
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                size: 16,
                              ),
                              if (flagged) const Icon(Icons.flag, size: 16),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16),
      const SizedBox(width: 4),
      Flexible(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
    ],
  );
}
