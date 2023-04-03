import 'package:in_app_purchases_paywall_ui/in_app_purchases_paywall_ui.dart';
import 'package:pilotiq/src/about/about.dart';
import 'package:pilotiq/src/home/home.dart';
import 'package:pilotiq/src/purchases/paywall.dart';

var appRoutes = {
  '/': (context) => const HomeScreen(),
  '/about': (context) => const AboutScreen(),
  '/paywall': (context) => const Paywall(),
};
