import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/subscription.dart';
import '../../services/session_service.dart';
import '../../services/subscription_service.dart';

/// Affiche [child] si le plan effectif de l'utilisateur courant (ou de
/// [userId] si fourni) est égal ou supérieur à [requiredPlan], sinon
/// affiche [fallback].
///
/// Ceci est un confort d'UX côté client (cacher un bouton, afficher un
/// cadenas) — la vérification qui compte réellement se fait toujours côté
/// serveur (Firestore Security Rules / Cloud Functions). Ne jamais se fier
/// uniquement à ce widget pour protéger une fonctionnalité sensible.
class PlanGuard extends ConsumerWidget {
  final SubscriptionPlan requiredPlan;
  final Widget child;
  final Widget fallback;
  final String? userId;

  const PlanGuard({
    super.key,
    required this.requiredPlan,
    required this.child,
    required this.fallback,
    this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = userId ?? ref.watch(sessionProvider).userId;
    return FutureBuilder<SubscriptionPlan>(
      future: ref.read(subscriptionServiceProvider).getCurrentPlan(uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final hasAccess = snapshot.data!.index >= requiredPlan.index;
        return hasAccess ? child : fallback;
      },
    );
  }
}

/// Variante pratique pour verrouiller une fonctionnalité Pro avec un badge
/// cadenas standard plutôt qu'un fallback personnalisé à chaque fois.
class ProLockedOverlay extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const ProLockedOverlay({super.key, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade500),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
