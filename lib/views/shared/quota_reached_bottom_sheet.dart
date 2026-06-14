import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/subscription.dart';

enum QuotaType { swipes, offers, conversations, boosts }

extension QuotaTypeExt on QuotaType {
  String get title {
    switch (this) {
      case QuotaType.swipes: return 'Quota de swipes atteint';
      case QuotaType.offers: return 'Limite d\'offres atteinte';
      case QuotaType.conversations: return 'Limite de conversations atteinte';
      case QuotaType.boosts: return 'Aucun boost disponible';
    }
  }

  IconData get icon {
    switch (this) {
      case QuotaType.swipes: return Icons.swipe_outlined;
      case QuotaType.offers: return Icons.work_outline;
      case QuotaType.conversations: return Icons.chat_bubble_outline;
      case QuotaType.boosts: return Icons.rocket_launch_outlined;
    }
  }
}

/// Bottom sheet réutilisable affiché quand un quota est atteint.
/// Affiche le temps avant le prochain reset (swipes uniquement).
class QuotaReachedBottomSheet extends StatelessWidget {
  final QuotaType quotaType;
  final SubscriptionPlan currentPlan;
  final DateTime? resetTime;

  const QuotaReachedBottomSheet({
    super.key,
    required this.quotaType,
    required this.currentPlan,
    this.resetTime,
  });

  String _resetCountdown() {
    if (resetTime == null) return '';
    final diff = resetTime!.difference(DateTime.now());
    if (diff.isNegative) return '';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    if (h > 0) return 'dans ${h}h ${m}min';
    return 'dans ${m}min';
  }

  String _planMessage() {
    switch (currentPlan) {
      case SubscriptionPlan.free:
        return 'Tu as atteint la limite du plan Gratuit. '
            'Passe au plan Starter ou Pro pour continuer.';
      case SubscriptionPlan.starter:
        return 'Tu as atteint la limite du plan Starter. '
            'Passe au plan Pro pour continuer sans limite.';
      case SubscriptionPlan.pro:
        return 'Quota de swipes épuisé. Il se rechargera bientôt.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final countdown = _resetCountdown();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Icon
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Icon(quotaType.icon, color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            quotaType.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Message
          Text(
            _planMessage(),
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          // Reset countdown (swipes uniquement)
          if (quotaType == QuotaType.swipes && countdown.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time, size: 14, color: AppColors.green),
                  const SizedBox(width: 6),
                  Text(
                    'Tes swipes se rechargent $countdown',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),

          // CTA
          if (currentPlan != SubscriptionPlan.pro)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/recruiter/plans');
                },
                icon: const Icon(Icons.arrow_upward, size: 18),
                label: const Text('Voir les plans',
                    style: TextStyle(fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Plus tard',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Affiche le bottom sheet de quota atteint.
Future<void> showQuotaReachedSheet(
  BuildContext context, {
  required QuotaType quotaType,
  required SubscriptionPlan currentPlan,
  DateTime? resetTime,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => QuotaReachedBottomSheet(
      quotaType: quotaType,
      currentPlan: currentPlan,
      resetTime: resetTime,
    ),
  );
}
