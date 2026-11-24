import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/purchases/paywall_text.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';

/// "Purchases" section of the settings: restore purchases (always reachable)
/// and where to cancel a subscription. State of its own: only the running
/// restore.
class PurchasesSettingsSection extends ConsumerStatefulWidget {
  const PurchasesSettingsSection({super.key});

  @override
  ConsumerState<PurchasesSettingsSection> createState() =>
      _PurchasesSettingsSectionState();
}

class _PurchasesSettingsSectionState
    extends ConsumerState<PurchasesSettingsSection> {
  bool _restoring = false;

  Future<void> _restore() async {
    if (_restoring) return;
    final messenger = ScaffoldMessenger.of(context);
    final local = AppLocalizations.of(context)!;
    setState(() => _restoring = true);
    String message;
    var retry = false;
    try {
      final state = await ref.read(purchaseServiceProvider).restore();
      message = state.isPremium
          ? local.paywallSettingsRestored
          : local.paywallRestoreNone;
    } on Object catch (e) {
      retry = true;
      message = purchaseFailureText(
        local,
        e is PurchaseException ? e.kind : PurchaseFailureKind.unknown,
      );
    }
    if (mounted) setState(() => _restoring = false);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: retry && mounted
              ? SnackBarAction(label: local.paywallRetry, onPressed: _restore)
              : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final available = ref.watch(purchaseServiceProvider).isAvailable;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Semantics(
            header: true,
            child: Text(
              local.paywallSettingsSection,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
        ListTile(
          key: const Key('settings_restore_purchases'),
          enabled: available && !_restoring,
          leading: const Icon(Icons.restore),
          title: Text(local.paywallSettingsRestoreTitle),
          subtitle: Text(
            available
                ? local.paywallSettingsRestoreSubtitle
                : local.paywallSettingsUnavailable,
          ),
          trailing: _restoring
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: available && !_restoring ? _restore : null,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            local.paywallSettingsManage,
            key: const Key('settings_manage_subscription'),
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
