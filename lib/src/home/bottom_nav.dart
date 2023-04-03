import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    return BottomNavigationBar(
      items: [
        BottomNavigationBarItem(
          icon: const Icon(
            FontAwesomeIcons.graduationCap,
            size: 20,
          ),
          label: local.examsTitle,
        ),
        BottomNavigationBarItem(
          icon: const Icon(
            FontAwesomeIcons.star,
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
            Navigator.pushNamed(context, '/paywall');
            break;
        }
      },
    );
  }
}
