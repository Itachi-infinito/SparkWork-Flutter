import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../../services/session_security_service.dart';
import '../../services/session_service.dart';

/// Bannière rouge persistante affichée en haut de toutes les pages quand le
/// compte recruteur est en mode restreint (anti-partage de compte).
/// Volontairement non-accusatrice — formulée en termes de protection.
class RestrictedModeBanner extends ConsumerWidget {
  const RestrictedModeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    if (!session.isLoggedIn || !session.isRecruiter) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<bool>(
      stream: ref.watch(sessionSecurityServiceProvider).watchRestrictedStatus(session.userId),
      builder: (context, snap) {
        if (snap.data != true) return const SizedBox.shrink();
        return Material(
          color: AppColors.red,
          child: SafeArea(
            bottom: false,
            child: InkWell(
              onTap: () => context.push('/security/unlock'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Votre compte est temporairement restreint pour des raisons de sécurité.',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Text('Débloquer',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
