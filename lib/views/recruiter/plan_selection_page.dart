import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/subscription.dart';
import '../../services/session_service.dart';
import '../../services/subscription_service.dart';
import '../../l10n/generated/app_localizations.dart';

class PlanSelectionPage extends ConsumerStatefulWidget {
  const PlanSelectionPage({super.key});

  @override
  ConsumerState<PlanSelectionPage> createState() => _PlanSelectionPageState();
}

class _PlanSelectionPageState extends ConsumerState<PlanSelectionPage> {
  RecruiterSubscription? _currentSub;
  bool _loading = true;
  String? _processingPlan;
  bool _restoring = false;
  bool _paymentsAvailable = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool sync = true}) async {
    final session = ref.read(sessionProvider);
    final svc = ref.read(subscriptionServiceProvider);
    // Réconcilie l'état réel depuis RevenueCat avant de lire Firestore, pour
    // ne pas afficher un plan périmé (achat/annulation non encore propagés).
    if (sync) await svc.syncSubscriptionStatus();
    final sub = await svc.getSubscription(session.userId);
    if (mounted) {
      setState(() {
        _currentSub = sub;
        _paymentsAvailable = svc.isRevenueCatConfigured;
        _loading = false;
      });
    }
  }

  Future<void> _selectPlan(SubscriptionPlan plan) async {
    if (plan == SubscriptionPlan.free) {
      // Gestion/résiliation centralisée dans la page « Mon abonnement » —
      // évite les messages contradictoires entre les deux écrans.
      context.push('/recruiter/subscription');
      return;
    }

    // Garde-fou : si les paiements ne sont pas disponibles sur cet appareil,
    // on prévient clairement au lieu de lancer un achat voué à échouer.
    if (!_paymentsAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context)!.planSelPaymentsUnavailableSnack),
        backgroundColor: AppColors.red,
      ));
      return;
    }

    final confirmed = await _showPurchaseConfirmationSheet(plan);
    if (confirmed != true || !mounted) return;
    final loc = AppLocalizations.of(context)!;

    setState(() => _processingPlan = plan.name);
    try {
      final svc = ref.read(subscriptionServiceProvider);
      final result = await svc.purchasePlan(plan);

      if (!mounted) return;

      if (result.isSuccess) {
        // Le document Firestore est mis à jour par le webhook RevenueCat
        // (peut prendre quelques secondes) — on recharge pour refléter l'état.
        await _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(loc.planSelWelcomePlan(plan.displayName)),
          backgroundColor: AppColors.green,
        ));
        context.go(ref.read(sessionProvider).isCandidate
            ? '/candidate/home'
            : '/recruiter/home');
      } else {
        _showPurchaseError(result);
      }
    } finally {
      if (mounted) setState(() => _processingPlan = null);
    }
  }

  void _showPurchaseError(PurchaseResult result) {
    final loc = AppLocalizations.of(context)!;
    String message;
    switch (result.outcome) {
      case PurchaseOutcome.userCancelled:
        return; // L'utilisateur a annulé lui-même — pas besoin de l'avertir.
      case PurchaseOutcome.networkError:
        message = result.message ?? loc.planSelNetworkError;
        break;
      case PurchaseOutcome.notConfigured:
        message = result.message ?? loc.planSelPaymentsUnavailable;
        break;
      case PurchaseOutcome.paymentError:
      default:
        message = loc.planSelPaymentFailed;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppColors.red,
    ));
  }

  Future<bool?> _showPurchaseConfirmationSheet(SubscriptionPlan plan) {
    final loc = AppLocalizations.of(context)!;
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(loc.planSelSwitchToPlan(plan.displayName),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary),
                children: [
                  TextSpan(text: '${plan.monthlyPrice.toInt()}€'),
                  TextSpan(text: loc.planSelPerMonth, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.normal)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              loc.planSelBillingInfo,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(loc.planSelCancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(loc.planSelConfirm, style: const TextStyle(color: Colors.white)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _restorePurchases() async {
    setState(() => _restoring = true);
    try {
      final svc = ref.read(subscriptionServiceProvider);
      final restored = await svc.restorePurchases();
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(restored
            ? loc.planSelRestoreSuccess
            : loc.planSelRestoreNone),
        backgroundColor: restored ? AppColors.green : AppColors.textSecondary,
      ));
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4C1D95), AppColors.primary, Color(0xFFEC4899)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(loc.planSelChooseYourPlan,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(loc.planSelSubtitle,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_currentSub?.isTrialActive == true)
                    _TrialBanner(daysLeft: _currentSub!.trialDaysRemaining),
                  if (!_paymentsAvailable) const _PaymentsUnavailableBanner(),
                  const SizedBox(height: 16),
                  _PlanCard(
                    plan: SubscriptionPlan.free,
                    currentSub: _currentSub,
                    isProcessing: _processingPlan == SubscriptionPlan.free.name,
                    onSelect: _selectPlan,
                  ),
                  const SizedBox(height: 16),
                  _PlanCard(
                    plan: SubscriptionPlan.starter,
                    currentSub: _currentSub,
                    isProcessing: _processingPlan == SubscriptionPlan.starter.name,
                    onSelect: _selectPlan,
                  ),
                  const SizedBox(height: 16),
                  _PlanCard(
                    plan: SubscriptionPlan.pro,
                    currentSub: _currentSub,
                    isProcessing: _processingPlan == SubscriptionPlan.pro.name,
                    onSelect: _selectPlan,
                    highlighted: true,
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton.icon(
                      onPressed: _restoring ? null : _restorePurchases,
                      icon: _restoring
                          ? const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.restore, size: 18),
                      label: Text(loc.planSelRestorePurchases),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _LegalNote(),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrialBanner extends StatelessWidget {
  final int daysLeft;
  const _TrialBanner({required this.daysLeft});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4C1D95), AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.star, color: Colors.amber, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.planSelTrialActive,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                Text(loc.planSelTrialDaysLeft(daysLeft),
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentsUnavailableBanner extends StatelessWidget {
  const _PaymentsUnavailableBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.orangeLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.orange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.planSelPaymentsUnavailableBanner,
              style: const TextStyle(color: AppColors.orange, fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final RecruiterSubscription? currentSub;
  final bool isProcessing;
  final bool highlighted;
  final void Function(SubscriptionPlan) onSelect;

  const _PlanCard({
    required this.plan,
    required this.currentSub,
    required this.isProcessing,
    required this.onSelect,
    this.highlighted = false,
  });

  bool get _isCurrent {
    final sub = currentSub;
    if (sub == null) return plan == SubscriptionPlan.free;
    return sub.effectivePlan == plan;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final features = _features(plan, loc);
    final isPro = plan == SubscriptionPlan.pro;
    final borderColor = highlighted ? AppColors.primary : Colors.grey.shade200;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor,
          width: highlighted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: highlighted
                ? AppColors.primary.withOpacity(0.15)
                : Colors.black.withOpacity(0.04),
            blurRadius: highlighted ? 16 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: highlighted
                  ? const LinearGradient(
                      colors: [Color(0xFF4C1D95), AppColors.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: highlighted ? null : Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            plan.displayName,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: highlighted ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          if (highlighted) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(loc.planSelRecommended,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (plan.monthlyPrice == 0)
                        Text(loc.subMgmtFree,
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: highlighted ? Colors.white : AppColors.primary))
                      else
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '${plan.monthlyPrice.toInt()}€',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: highlighted ? Colors.white : AppColors.primary,
                                ),
                              ),
                              TextSpan(
                                text: loc.planSelPerMonth,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: highlighted
                                      ? Colors.white70
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (isPro)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withOpacity(0.5)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(height: 2),
                        Text(loc.planSelTrialDaysFree,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Features
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              children: features
                  .map((f) => _FeatureLine(text: f.$1, included: f.$2))
                  .toList(),
            ),
          ),

          // CTA
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: _isCurrent
                  ? OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check_circle_outline,
                          color: AppColors.green),
                      label: Text(loc.planSelCurrentPlan,
                          style: const TextStyle(color: AppColors.green)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.green),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    )
                  : plan == SubscriptionPlan.free
                      ? OutlinedButton(
                          onPressed: isProcessing
                              ? null
                              : () => onSelect(plan),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.red.withOpacity(0.5)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(loc.planSelManageSubscription,
                              style: const TextStyle(color: AppColors.red, fontSize: 13)),
                        )
                      : ElevatedButton(
                          onPressed: isProcessing ? null : () => onSelect(plan),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: highlighted
                                ? AppColors.primary
                                : Colors.grey.shade800,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: isProcessing
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : Text(loc.planSelChoosePlan(plan.displayName)),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  List<(String, bool)> _features(SubscriptionPlan p, AppLocalizations loc) {
    switch (p) {
      case SubscriptionPlan.free:
        return [
          (loc.planFeatureFreeSwipes, true),
          (loc.planFeatureFreeOffers, true),
          (loc.planFeatureFreeConversations, true),
          (loc.planSelFeatureBoosts, false),
          (loc.planSelFeatureStats, false),
          (loc.planFeatureVerifiedBadge, false),
        ];
      case SubscriptionPlan.starter:
        return [
          (loc.planFeatureStarterSwipes, true),
          (loc.planFeatureStarterOffers, true),
          (loc.planFeatureUnlimitedConversations, true),
          (loc.planFeatureStarterBoost, true),
          (loc.planFeatureStarterStats, true),
          (loc.planFeatureVerifiedBadge, false),
        ];
      case SubscriptionPlan.pro:
        return [
          (loc.planFeatureProSwipes, true),
          (loc.planFeatureProOffers, true),
          (loc.planFeatureUnlimitedConversations, true),
          (loc.planFeatureProBoosts, true),
          (loc.planFeatureProStats, true),
          (loc.planSelFeatureVerifiedBadgeCheck, true),
        ];
    }
  }
}

class _FeatureLine extends StatelessWidget {
  final String text;
  final bool included;
  const _FeatureLine({required this.text, required this.included});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            included ? Icons.check_circle : Icons.cancel_outlined,
            size: 18,
            color: included ? AppColors.green : Colors.grey.shade400,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: included ? AppColors.textPrimary : AppColors.textHint,
                decoration: included ? null : TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalNote extends StatelessWidget {
  const _LegalNote();

  @override
  Widget build(BuildContext context) {
    return Text(
      AppLocalizations.of(context)!.planSelLegalNote,
      style: const TextStyle(
        fontSize: 12,
        color: AppColors.textHint,
        height: 1.5,
      ),
      textAlign: TextAlign.center,
    );
  }
}
