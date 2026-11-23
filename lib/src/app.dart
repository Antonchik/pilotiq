import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:pilotiq/src/dark_theme/theme_mode_provider.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/progress/legacy_migration.dart';
import 'package:pilotiq/src/progress/providers.dart';
import 'package:pilotiq/src/routes.dart';
import 'package:pilotiq/src/theme.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      restorationScopeId: 'app',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      onGenerateTitle: (BuildContext context) =>
          AppLocalizations.of(context)!.appTitle,
      theme: lightAppTheme,
      darkTheme: darkAppTheme,
      themeMode: ref.watch(themeModeProvider),
      routes: appRoutes,
    );
  }
}

/// Start-up order: the legacy migration runs first, before anything reads the
/// settings (a settings object read before the migration and saved after it
/// would overwrite the migrated theme). A failed migration does not stop the
/// start: the app runs with the default settings, the old boxes stay as they
/// are and the migration is tried again at the next launch.
Future<MigrationOutcome> runStartupMigration(
  ProviderContainer container,
) async {
  final outcome = await container.read(legacyMigrationProvider).run();
  // Drop anything that might have been computed from the pre-migration data.
  container.invalidate(userSettingsProvider);
  return outcome;
}

/// Opens Hive, runs the migration and returns the container the app runs in.
Future<ProviderContainer> initializeApp() async {
  await Hive.initFlutter();
  final container = ProviderContainer();
  try {
    await runStartupMigration(container);
  } on Object {
    container.dispose();
    rethrow;
  }
  return container;
}

/// Root widget: initialises the app and shows a retry screen if that fails.
class PilotiqRoot extends StatefulWidget {
  const PilotiqRoot({super.key, this.initialize = initializeApp});

  final Future<ProviderContainer> Function() initialize;

  @override
  State<PilotiqRoot> createState() => _PilotiqRootState();
}

class _PilotiqRootState extends State<PilotiqRoot> {
  late Future<ProviderContainer> _start = _begin();

  /// Starts the initialisation. A failure (also a synchronous one) is
  /// reported by the screen, never as an unhandled error.
  Future<ProviderContainer> _begin() {
    final start = Future<ProviderContainer>.sync(widget.initialize);
    start.ignore();
    return start;
  }

  @override
  void dispose() {
    // The container lives as long as this widget.
    _start.then((c) => c.dispose(), onError: (Object _) {});
    super.dispose();
  }

  void _retry() {
    setState(() {
      _start = _begin();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProviderContainer>(
      future: _start,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return UncontrolledProviderScope(
            container: snapshot.data!,
            child: const MyApp(),
          );
        }
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: lightAppTheme,
          darkTheme: darkAppTheme,
          home: snapshot.hasError
              ? _StartupErrorScreen(onRetry: _retry)
              : const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
        );
      },
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                local.startupErrorTitle,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(local.settingsStartupError, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('startup_retry'),
                onPressed: onRetry,
                child: Text(local.settingsRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
