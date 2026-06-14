import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../models/subscription.dart';
import '../../services/session_service.dart';
import '../../services/subscription_service.dart';

class PlanSelectionPage extends ConsumerStatefulWidget {
  const PlanSelectionPage({super.key});

  @override
  ConsumerState<PlanSelectionPage> createState() => _PlanSelectionPageState();
}

class _PlanSelectionPageState extends ConsumerState<PlanSelectionPage> {
  RecruiterSubscription? _currentSub;
  bool _loading = true;
  String? _processingPlan;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = ref.read(sessionProvider);
    final svc = ref.read(subscriptionServiceProvider);
    final sub = await svc.getSubscription(session.userId);
    if (mounted) setState(() { _currentSub = sub; _loading = false; });
  }

  Future<void> _selectPlan(SubscriptionPlan plan) async {
    if (plan == SubscriptionPlan.free) return; // downgrade non disponible ici
    setState(() => _processingPlan = plan.name);
    try {
      final session = ref.read(sessionProvider);
      final svc = ref.read(subscriptionServiceProvider);
      // TODO: connect RevenueCat — appeler Purchases.purchasePackage(plan.productId)
      await svc.upgradePlan(session.userId, plan);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Plan ${plan.displayName} activé !'),
        backgroundColor: AppColors.green,
      ));
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: AppColors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _processingPlan = null);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                child: const SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 60, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Choisissez votre plan',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Recrutez mieux, recrutez plus vite',
                            style: TextStyle(
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
                  const SizedBox(height: 32),
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
                const Text('Essai Pro en cours',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                Text('$daysLeft jour${daysLeft > 1 ? 's' : ''} restant${daysLeft > 1 ? 's' : ''}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
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
    final features = _features(plan);
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
                              child: const Text('Recommandé',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (plan.monthlyPrice == 0)
                        Text('Gratuit',
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
                                text: '/mois',
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
                    child: const Column(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 16),
                        SizedBox(height: 2),
                        Text('14 jours\ngratuits',
                            textAlign: TextAlign.center,
                            style: TextStyle(
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
                      label: const Text('Plan actuel',
                          style: TextStyle(color: AppColors.green)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.green),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    )
                  : plan == SubscriptionPlan.free
                      ? OutlinedButton(
                          onPressed: null,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Gratuit',
                              style: TextStyle(color: AppColors.textSecondary)),
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
                              : Text('Choisir ${plan.displayName}'),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  List<(String, bool)> _features(SubscriptionPlan p) {
    switch (p) {
      case SubscriptionPlan.free:
        return [
          ('5 swipes par jour', true),
          ('1 offre active maximum', true),
          ('3 conversations simultanées', true),
          ('Boosts d\'offre', false),
          ('Statistiques', false),
          ('Badge Employeur vérifié', false),
        ];
      case SubscriptionPlan.starter:
        return [
          ('50 swipes par jour', true),
          ('3 offres actives simultanées', true),
          ('Conversations illimitées', true),
          ('1 boost d\'offre par mois', true),
          ('Stats : vues, taux de match', true),
          ('Badge Employeur vérifié', false),
        ];
      case SubscriptionPlan.pro:
        return [
          ('Swipes illimités', true),
          ('10 offres actives simultanées', true),
          ('Conversations illimitées', true),
          ('3 boosts d\'offre par mois', true),
          ('Stats avancées + profils intéressés', true),
          ('Badge Employeur vérifié ✓', true),
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
    return const Text(
      'Les abonnements sont mensuels et résiliables à tout moment. '
      'Le plan Pro inclut 14 jours d\'essai gratuit sans engagement '
      'pour les nouveaux comptes recruteurs.',
      style: TextStyle(
        fontSize: 12,
        color: AppColors.textHint,
        height: 1.5,
      ),
      textAlign: TextAlign.center,
    );
  }
}
