import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:pilotiq/src/dark_theme/theme_mode_provider.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/notifications/reminder_host.dart';
import 'package:pilotiq/src/progress/legacy_migration.dart';
import 'package:pilotiq/src/progress/providers.dart';
import 'package:pilotiq/src/purchases/purchase_bootstrap.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';
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
      builder: (context, child) =>
          ReminderLifecycleHost(child: child ?? const SizedBox.shrink()),
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
  // Finish an answer record that was interrupted by the last run, so that the
  // first reads (the dashboard) never see a partly applied answer. Failure is
  // not fatal: the next locked write repeats it.
  try {
    await container.read(progressRepositoryProvider).recoverPending();
  } on Object {
    // see above
  }
  // Drop anything that might have been computed from the pre-migration data.
  container.invalidate(userSettingsProvider);
  return outcome;
}

/// Opens Hive, starts the purchases, runs the migration and returns the
/// container the app runs in. Purchases never fail the start (without keys or
/// if the store SDK cannot start the app runs without purchases).
Future<ProviderContainer> initializeApp() async {
  await Hive.initFlutter();
  final purchases = await createPurchaseService();
  final container = ProviderContainer(
    overrides: [
      purchaseServiceProvider.overrideWith((ref) {
        ref.onDispose(purchases.dispose);
        return purchases;
      }),
    ],
  );
  try {
    await runStartupMigration(container);
  } on Object {
    container.dispose();
    purchases.dispose();
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
  /// Number of the current start; an answer of an older start is stale.
  int _generation = 0;
  ProviderContainer? _container;
  Object? _error;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _begin();
  }

  /// Starts the initialisation. A failure (also a synchronous one) is
  /// reported by the screen, never as an unhandled error. While a start is
  /// running the loading indicator is shown, never the old error screen.
  void _begin() {
    final generation = ++_generation;
    _error = null;
    Future<ProviderContainer>.sync(widget.initialize).then(
      (container) {
        if (_disposed || generation != _generation) {
          // Replaced or disposed while it was starting: nobody will use it.
          container.dispose();
          return;
        }
        setState(() => _container = container);
      },
      onError: (Object error) {
        if (_disposed || generation != _generation) return;
        setState(() => _error = error);
      },
    );
  }

  @override
  void dispose() {
    _disposed = true;
    // The container lives as long as this widget.
    _container?.dispose();
    super.dispose();
  }

  void _retry() {
    // Retry is only offered on the error screen, i.e. when no start runs.
    if (_error == null || _container != null) return;
    setState(_begin);
  }

  @override
  Widget build(BuildContext context) {
    final container = _container;
    if (container != null) {
      return UncontrolledProviderScope(
        container: container,
        child: const MyApp(),
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: lightAppTheme,
      darkTheme: darkAppTheme,
      home: _error != null
          ? _StartupErrorScreen(onRetry: _retry)
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
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
