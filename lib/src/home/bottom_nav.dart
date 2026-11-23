import 'package:flutter/material.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/purchases/paywall_launcher.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    return BottomNavigationBar(
      items: [
        BottomNavigationBarItem(
          icon: const Icon(
            Icons.school,
            size: 20,
          ),
          label: local.examsTitle,
        ),
        BottomNavigationBarItem(
          icon: const Icon(
            Icons.star,
            size: 20,
          ),
          label: local.premiumLabel,
        ),
      ],
      onTap: (int idx) {
        switch (idx) {
          case 0:
            // do nothing
            break;
          case 1:
            openPaywall(context, trigger: PaywallTrigger.profile);
            break;
        }
      },
    );
  }
}
