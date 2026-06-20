import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../models/subscription.dart';
import '../../services/session_service.dart';
import '../../services/subscription_service.dart';

class SubscriptionManagementPage extends ConsumerStatefulWidget {
  const SubscriptionManagementPage({super.key});

  @override
  ConsumerState<SubscriptionManagementPage> createState() =>
      _SubscriptionManagementPageState();
}

class _SubscriptionManagementPageState
    extends ConsumerState<SubscriptionManagementPage> {
  RecruiterSubscription? _sub;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final session = ref.read(sessionProvider);
    final sub = await ref.read(subscriptionServiceProvider).getSubscription(session.userId);
    if (mounted) setState(() { _sub = sub; _loading = false; });
  }

  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler l\'abonnement'),
        content: const Text(
          'Vous allez être redirigé vers la gestion d\'abonnement de votre '
          'store. Votre accès reste actif jusqu\'à la fin de la période déjà payée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Retour'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continuer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(subscriptionServiceProvider).openManageSubscriptions();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Une fois confirmé dans le store, votre statut se met à jour automatiquement.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mon abonnement')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_sub?.isTrialActive == true) _buildTrialBanner(_sub!),
                  if (_sub?.status == 'expired') _buildExpiredBanner(),
                  if (_sub?.cancelAtPeriodEnd == true) _buildCancelledBanner(_sub!),
                  const SizedBox(height: 16),
                  _buildPlanCard(_sub),
                  const SizedBox(height: 24),
                  _buildFeaturesList(_sub?.effectivePlan ?? SubscriptionPlan.free),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/recruiter/plans'),
                      icon: const Icon(Icons.swap_horiz, color: Colors.white),
                      label: const Text('Changer de plan',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ),
                  if (_sub != null &&
                      _sub!.effectivePlan != SubscriptionPlan.free &&
                      !_sub!.isTrialActive &&
                      !_sub!.cancelAtPeriodEnd) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _confirmCancel,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.red.withOpacity(0.5)),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text('Annuler l\'abonnement',
                            style: TextStyle(color: AppColors.red)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildTrialBanner(RecruiterSubscription sub) {
    final progress = (14 - sub.trialDaysRemaining) / 14;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF4C1D95), AppColors.primary]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.star, color: Colors.amber, size: 20),
            const SizedBox(width: 8),
            Text('Essai Pro — ${sub.trialDaysRemaining} jour${sub.trialDaysRemaining > 1 ? 's' : ''} restant${sub.trialDaysRemaining > 1 ? 's' : ''}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.25),
              valueColor: const AlwaysStoppedAnimation(Colors.amber),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiredBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.redLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.red.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: AppColors.red),
        const SizedBox(width: 12),
        const Expanded(
          child: Text('Votre abonnement a expiré.',
              style: TextStyle(color: AppColors.red, fontWeight: FontWeight.bold)),
        ),
        TextButton(
          onPressed: () => context.push('/recruiter/plans'),
          child: const Text('Renouveler', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  Widget _buildCancelledBanner(RecruiterSubscription sub) {
    final endDateLabel = sub.endDate != null
        ? DateFormat('d MMMM yyyy', 'fr_FR').format(sub.endDate!)
        : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.orangeLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        const Icon(Icons.info_outline, color: AppColors.orange),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Renouvellement désactivé — accès actif jusqu\'au $endDateLabel.',
            style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ]),
    );
  }

  Widget _buildPlanCard(RecruiterSubscription? sub) {
    final plan = sub?.effectivePlan ?? SubscriptionPlan.free;
    final renewalLabel = sub?.endDate != null
        ? DateFormat('d MMMM yyyy', 'fr_FR').format(sub!.endDate!)
        : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _planColor(plan).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(plan.displayName,
                  style: TextStyle(color: _planColor(plan), fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            const Spacer(),
            Text(plan.monthlyPrice == 0 ? 'Gratuit' : '${plan.monthlyPrice.toInt()}€/mois',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          if (renewalLabel != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.event_repeat, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                sub?.cancelAtPeriodEnd == true
                    ? 'Expire le $renewalLabel'
                    : 'Prochain renouvellement : $renewalLabel',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Color _planColor(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free: return AppColors.textSecondary;
      case SubscriptionPlan.starter: return AppColors.primary;
      case SubscriptionPlan.pro: return Colors.amber.shade800;
    }
  }

  Widget _buildFeaturesList(SubscriptionPlan plan) {
    final features = switch (plan) {
      SubscriptionPlan.free => const [
          '5 swipes par jour',
          '1 offre active maximum',
          '3 conversations simultanées',
        ],
      SubscriptionPlan.starter => const [
          '50 swipes par jour',
          '3 offres actives simultanées',
          'Conversations illimitées',
          '1 boost d\'offre par mois',
          'Stats : vues, taux de match',
        ],
      SubscriptionPlan.pro => const [
          'Swipes illimités',
          '10 offres actives simultanées',
          'Conversations illimitées',
          '3 boosts d\'offre par mois',
          'Stats avancées + profils intéressés',
          'Badge Employeur vérifié',
          'Gestion d\'équipe',
          'Insights sectoriels',
        ],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Inclus dans votre plan',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...features.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                const Icon(Icons.check_circle, size: 16, color: AppColors.green),
                const SizedBox(width: 8),
                Expanded(child: Text(f, style: const TextStyle(fontSize: 13))),
              ]),
            )),
      ],
    );
  }
}
