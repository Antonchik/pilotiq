import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pilotiq/src/about/legal_links.dart';
import 'package:pilotiq/src/domain/access_policy.dart';
import 'package:pilotiq/src/domain/dates.dart';
import 'package:pilotiq/src/localization/generated/app_localizations.dart';
import 'package:pilotiq/src/progress/providers.dart';
import 'package:pilotiq/src/purchases/paywall_launcher.dart';
import 'package:pilotiq/src/purchases/paywall_text.dart';
import 'package:pilotiq/src/purchases/purchase_service.dart';
import 'package:url_launcher/url_launcher.dart';

enum _Phase { loading, ready, empty, error, unavailable }

/// What the banner under the plans says.
enum _Notice { pending, restoreNone }

/// The paywall: plans from the store, a purchase, restore, the terms of the
/// subscriptions and the legal links. The state belongs to this screen only.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key, required this.trigger});

  final PaywallTrigger trigger;

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  _Phase _phase = _Phase.loading;
  List<PaywallPackage> _packages = const [];
  PurchaseFailureKind _loadError = PurchaseFailureKind.unknown;
  String? _selectedId;

  /// A purchase or a restore is running: every action is switched off, so a
  /// second tap cannot start a second purchase.
  bool _busy = false;
  _Notice? _notice;
  PurchaseFailureKind? _actionError;
  Future<void> Function()? _retryAction;

  /// Premium came from this screen (purchase or restore), as opposed to being
  /// active already when the screen opened.
  bool _justUnlocked = false;
  late final bool _premiumOnOpen;
  int _loadSerial = 0;

  PurchaseService get _service => ref.read(purchaseServiceProvider);

  @override
  void initState() {
    super.initState();
    _premiumOnOpen = ref.read(isPremiumProvider);
    _load();
  }

  Future<void> _load() async {
    final serial = ++_loadSerial;
    final service = _service;
    if (!service.isAvailable) {
      setState(() => _phase = _Phase.unavailable);
      return;
    }
    setState(() => _phase = _Phase.loading);
    try {
      final packages = await service.getOffering();
      if (!mounted || serial != _loadSerial) return;
      setState(() {
        _packages = packages;
        _phase = packages.isEmpty ? _Phase.empty : _Phase.ready;
        if (!packages.any((p) => p.id == _selectedId)) _selectedId = null;
      });
    } on Object catch (e) {
      if (!mounted || serial != _loadSerial) return;
      setState(() {
        _loadError = e is PurchaseException
            ? e.kind
            : PurchaseFailureKind.unknown;
        _phase = _Phase.error;
      });
    }
  }

  Future<void> _buy() async {
    final id = _selectedId;
    if (id == null || _busy) return;
    setState(() {
      _busy = true;
      _notice = null;
      _actionError = null;
    });
    try {
      final outcome = await _service.purchase(id);
      if (!mounted) return;
      setState(() {
        switch (outcome) {
          case PurchaseOutcome.purchased:
            _justUnlocked = true;
          case PurchaseOutcome.pending:
            _notice = _Notice.pending;
          case PurchaseOutcome.cancelled:
            break;
        }
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _actionError = _kindOf(e);
        _retryAction = _buy;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _notice = null;
      _actionError = null;
    });
    try {
      final state = await _service.restore();
      if (!mounted) return;
      setState(() {
        if (state.isPremium) {
          _justUnlocked = true;
        } else {
          _notice = _Notice.restoreNone;
        }
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _actionError = _kindOf(e);
        _retryAction = _restore;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static PurchaseFailureKind _kindOf(Object e) =>
      e is PurchaseException ? e.kind : PurchaseFailureKind.unknown;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final premium = ref.watch(isPremiumProvider) || _justUnlocked;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          key: const Key('paywall_close'),
          icon: const Icon(Icons.close),
          tooltip: local.paywallClose,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(local.premiumTitle),
      ),
      body: SafeArea(
        child: premium
            ? _UnlockedView(justUnlocked: _justUnlocked || !_premiumOnOpen)
            : _buildOffer(context, local),
      ),
    );
  }

  Widget _buildOffer(BuildContext context, AppLocalizations local) {
    final theme = Theme.of(context);
    final settings = ref.watch(userSettingsProvider).value;
    final examDate = settings?.examDate;
    final daysLeft = examDate == null
        ? null
        : calendarDaysBetween(ref.watch(clockProvider).now(), examDate);
    final (title, subtitle) = _headline(local);
    final subscriptions = _packages.where((p) => p.isSubscription);
    final hasLifetime = _packages.any((p) => !p.isSubscription);
    final hasTrial = subscriptions.any((p) => p.introOffer?.isFree ?? false);
    final showTerms = _phase == _Phase.ready;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            key: const Key('paywall_title'),
            style: theme.textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 8),
        Text(subtitle, key: const Key('paywall_subtitle')),
        if (daysLeft != null && daysLeft >= 0) ...[
          const SizedBox(height: 8),
          Text(
            local.dashboardExamCountdown(daysLeft),
            key: const Key('paywall_exam_countdown'),
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
        const SizedBox(height: 16),
        _Benefits(local: local),
        const SizedBox(height: 16),
        ..._buildPlans(context, local),
        if (showTerms) ...[
          const SizedBox(height: 16),
          if (subscriptions.isNotEmpty)
            Text(
              local.paywallRenewalNotice,
              key: const Key('paywall_renewal_notice'),
              style: theme.textTheme.bodySmall,
            ),
          if (hasTrial) ...[
            const SizedBox(height: 8),
            Text(
              local.paywallTrialNotice,
              key: const Key('paywall_trial_notice'),
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (hasLifetime) ...[
            const SizedBox(height: 8),
            Text(
              local.paywallOneTimeNotice,
              key: const Key('paywall_one_time_notice'),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
        const SizedBox(height: 8),
        const _LegalLinks(),
      ],
    );
  }

  (String, String) _headline(AppLocalizations l) => switch (widget.trigger) {
    PaywallTrigger.dailyLimit => (
      l.paywallTitleDailyLimit,
      l.paywallSubtitleDailyLimit(AccessPolicy.freeDailyAnswers),
    ),
    PaywallTrigger.examLimit => (
      l.paywallTitleExamLimit,
      l.paywallSubtitleExamLimit(AccessPolicy.freeExamsPerSubject),
    ),
    PaywallTrigger.lockedFeature => (
      l.paywallTitleLocked,
      l.paywallSubtitleLocked,
    ),
    PaywallTrigger.examResults => (
      l.paywallTitleResults,
      l.paywallSubtitleResults,
    ),
    PaywallTrigger.profile => (
      l.paywallTitleProfile,
      l.paywallSubtitleProfile,
    ),
  };

  List<Widget> _buildPlans(BuildContext context, AppLocalizations local) {
    switch (_phase) {
      case _Phase.loading:
        return [
          Semantics(
            liveRegion: true,
            child: Column(
              key: const Key('paywall_loading'),
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
                Text(local.paywallLoading, textAlign: TextAlign.center),
              ],
            ),
          ),
        ];
      case _Phase.unavailable:
        return [
          _Message(
            key: const Key('paywall_unavailable'),
            icon: Icons.info_outline,
            text: local.paywallUnavailable,
          ),
        ];
      case _Phase.error:
        return [
          _Message(
            key: const Key('paywall_error'),
            icon: Icons.error_outline,
            text: purchaseFailureText(local, _loadError),
            retryLabel: local.paywallRetry,
            onRetry: _load,
          ),
        ];
      case _Phase.empty:
        return [
          _Message(
            key: const Key('paywall_empty'),
            icon: Icons.info_outline,
            text: local.paywallEmpty,
            retryLabel: local.paywallRetry,
            onRetry: _load,
          ),
        ];
      case _Phase.ready:
        break;
    }
    final theme = Theme.of(context);
    final showBadge = _packages.length > 1;
    return [
      Semantics(
        header: true,
        child: Text(local.paywallChoosePlan, style: theme.textTheme.titleMedium),
      ),
      const SizedBox(height: 8),
      for (final p in _packages)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _PlanTile(
            package: p,
            selected: p.id == _selectedId,
            enabled: !_busy,
            showBestChoice: showBadge && p.kind == PackageKind.lifetime,
            onTap: () => setState(() => _selectedId = p.id),
          ),
        ),
      if (_busy)
        Semantics(
          liveRegion: true,
          child: Column(
            key: const Key('paywall_purchasing'),
            children: [
              const LinearProgressIndicator(),
              const SizedBox(height: 4),
              Text(local.paywallPurchasing, textAlign: TextAlign.center),
            ],
          ),
        ),
      if (_notice == _Notice.pending)
        _Message(
          key: const Key('paywall_pending'),
          icon: Icons.hourglass_empty,
          text: local.paywallPending,
        ),
      if (_notice == _Notice.restoreNone)
        _Message(
          key: const Key('paywall_restore_none'),
          icon: Icons.info_outline,
          text: local.paywallRestoreNone,
        ),
      if (_actionError != null)
        _Message(
          key: const Key('paywall_action_error'),
          icon: Icons.error_outline,
          text: purchaseFailureText(local, _actionError!),
          retryLabel: local.paywallRetry,
          onRetry: _busy ? null : _retryAction,
        ),
      const SizedBox(height: 8),
      FilledButton(
        key: const Key('paywall_buy'),
        onPressed: _selectedId == null || _busy ? null : _buy,
        child: Text(local.paywallContinue),
      ),
      const SizedBox(height: 4),
      TextButton(
        key: const Key('paywall_restore'),
        onPressed: _busy ? null : _restore,
        child: Text(local.paywallRestore),
      ),
    ];
  }
}

class _Benefits extends StatelessWidget {
  const _Benefits({required this.local});

  final AppLocalizations local;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = [
      local.paywallBenefitUnlimited(AccessPolicy.freeDailyAnswers),
      local.paywallBenefitSimulations(AccessPolicy.freeExamsPerSubject),
      local.paywallBenefitMistakes,
      local.paywallBenefitReview,
      local.paywallBenefitReadiness,
    ];
    return Column(
      key: const Key('paywall_benefits'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            local.paywallBenefitsTitle,
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        for (final text in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(text)),
              ],
            ),
          ),
      ],
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.package,
    required this.selected,
    required this.enabled,
    required this.showBestChoice,
    required this.onTap,
  });

  final PaywallPackage package;
  final bool selected;
  final bool enabled;
  final bool showBestChoice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final name = planName(local, package);
    final price = planPriceText(local, package);
    final intro = introText(local, package);
    final best = showBestChoice ? local.paywallBestChoice : null;
    final semantics = [
      name,
      price,
      ?intro,
      ?best,
      selected ? local.paywallSemSelected : local.paywallSemNotSelected,
    ].join(', ');
    final border = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;
    return Semantics(
      key: Key('paywall_plan_${package.id}'),
      container: true,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      enabled: enabled,
      label: semantics,
      onTap: enabled ? onTap : null,
      child: ExcludeSemantics(
        child: Material(
          color: selected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
              : theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: border, width: selected ? 2 : 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: enabled ? onTap : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                name,
                                style: theme.textTheme.titleMedium,
                              ),
                              if (best != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    best,
                                    style: theme.textTheme.labelSmall
                                        ?.copyWith(
                                          color: theme.colorScheme.onPrimary,
                                        ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(price),
                          if (intro != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              intro,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An information or error message with an optional retry button.
class _Message extends StatelessWidget {
  const _Message({
    super.key,
    required this.icon,
    required this.text,
    this.retryLabel,
    this.onRetry,
  });

  final IconData icon;
  final String text;
  final String? retryLabel;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(child: Text(text)),
                ],
              ),
              if (retryLabel != null)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    key: const Key('paywall_retry'),
                    onPressed: onRetry == null ? null : () => onRetry!(),
                    child: Text(retryLabel!),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thanks after a purchase, or a note that Premium is active already.
class _UnlockedView extends StatelessWidget {
  const _UnlockedView({required this.justUnlocked});

  final bool justUnlocked;

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(
          Icons.verified,
          size: 64,
          color: theme.colorScheme.primary,
          semanticLabel: null,
        ),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            justUnlocked ? local.paywallThanksTitle : local.paywallAlreadyTitle,
            key: const Key('paywall_thanks_title'),
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          justUnlocked ? local.paywallThanksBody : local.paywallAlreadyBody,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('paywall_done'),
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(local.paywallContinue),
        ),
      ],
    );
  }
}

Future<void> _openLink(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } on Object {
    // Opening a link is best effort; there is nothing to recover.
  }
}

/// Terms of Service and Privacy Policy links, always visible.
class _LegalLinks extends StatelessWidget {
  const _LegalLinks();

  @override
  Widget build(BuildContext context) {
    final local = AppLocalizations.of(context)!;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: [
        TextButton(
          key: const Key('paywall_terms'),
          onPressed: () => _openLink(termsOfServiceUrl),
          child: Text(local.termsOfServiceLabel),
        ),
        TextButton(
          key: const Key('paywall_privacy'),
          onPressed: () => _openLink(privacyPolicyUrl),
          child: Text(local.privacyPolicyLabel),
        ),
      ],
    );
  }
}
