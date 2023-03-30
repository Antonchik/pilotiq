import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

Future<String> loadChangelog() async {
  return rootBundle.loadString('assets/changelog.md');
}

class ApplicationVersionWidget extends StatelessWidget {
  const ApplicationVersionWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (BuildContext context, AsyncSnapshot<PackageInfo> snapShot) {
        if (snapShot.connectionState == ConnectionState.done) {
          final local = AppLocalizations.of(context)!;
          final version = snapShot.data?.version;
          final title = snapShot.data?.appName;
          final copyright = local.copyright;
          final icon = Image.asset('assets/icon/launcher_icon.png', height: 90);
          final applicationVersion = 'v.$version';
          return IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showAboutDialog(
                context: context,
                applicationName: title,
                applicationVersion: applicationVersion,
                applicationLegalese: copyright,
                applicationIcon: icon,
              );
            },
          );
        } else {
          return const SizedBox.shrink();
        }
      },
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('about'),
        // backgroundColor: Colors.blue,
      ),
      body: const Center(
        child: Text('About this app...'),
      ),
    );
  }
}
