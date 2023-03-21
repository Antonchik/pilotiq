import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
          label: local.topicsTitle,
        ),
        BottomNavigationBarItem(
          icon: const Icon(
            FontAwesomeIcons.bolt,
            size: 20,
          ),
          label: local.aboutTitle,
        ),
      ],
      fixedColor: Colors.deepPurple[200],
      onTap: (int idx) {
        switch (idx) {
          case 0:
            // do nothing
            break;
          case 1:
            Navigator.pushNamed(context, '/about');
            break;
        }
      },
    );
  }
}
