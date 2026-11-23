import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

class ResultScaleBar extends StatelessWidget {
  const ResultScaleBar({
    super.key,
    required this.percent,
    this.header,
  });

  final double percent;
  final String? header;

  @override
  Widget build(BuildContext context) {
    return CircularPercentIndicator(
      radius: 100.0,
      lineWidth: 15.0,
      percent: percent,
      progressColor: Colors.green,
      arcBackgroundColor: Theme.of(context).colorScheme.primary,
      arcType: ArcType.HALF,
      circularStrokeCap: CircularStrokeCap.butt,
      animation: true,
      animationDuration: 2000,
      rotateLinearGradient: true,
      header: Text(
        header ?? '',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      center: Text('${(percent * 100).round()}%',
          style: Theme.of(context).textTheme.headlineSmall),
    );
  }
}
