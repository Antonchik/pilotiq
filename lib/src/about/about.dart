import 'package:flutter/material.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Package info is read from the platform once and then cached.
final packageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

class ApplicationVersionWidget extends ConsumerWidget {
  const ApplicationVersionWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(packageInfoProvider)
        .when(
          data: (info) {
            final local = AppLocalizations.of(context)!;
            final version = info.version;
            final title = info.appName;
            final copyright = local.copyright;
            final icon = Image.asset(
              'assets/icon/launcher_icon.png',
              height: 90,
            );
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
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.aboutTitle)),
      body: Center(child: Text(AppLocalizations.of(context)!.aboutScreenBody)),
    );
  }
}
