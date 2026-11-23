import 'package:pilotiq/src/about/about.dart';
import 'package:pilotiq/src/home/app_gate.dart';

final appRoutes = {
  '/': (context) => const AppGate(),
  '/about': (context) => const AboutScreen(),
};
