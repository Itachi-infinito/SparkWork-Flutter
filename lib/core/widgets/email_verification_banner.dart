import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';
import '../constants/app_colors.dart';

/// Bannière affichée tant que l'email n'est pas vérifié.
/// Se masque automatiquement après vérification (bouton "J'ai vérifié").
class EmailVerificationBanner extends ConsumerStatefulWidget {
  const EmailVerificationBanner({super.key});

  @override
  ConsumerState<EmailVerificationBanner> createState() =>
      _EmailVerificationBannerState();
}

class _EmailVerificationBannerState
    extends ConsumerState<EmailVerificationBanner> {
  bool _verified = true; // true par défaut = bannière cachée
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await user.reload();
    } catch (_) {}
    final fresh = FirebaseAuth.instance.currentUser;
    if (mounted) setState(() => _verified = fresh?.emailVerified ?? true);
  }

  Future<void> _resend() async {
    setState(() => _sending = true);
    final (ok, msg) =
        await ref.read(authServiceProvider).resendVerificationEmail();
    if (mounted) {
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? 'Email de vérification renvoyé !'
            : 'Échec de l\'envoi : $msg'),
        backgroundColor: ok ? AppColors.green : AppColors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_verified) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.orangeLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.orange.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.mark_email_unread_outlined,
                  color: AppColors.orange, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Vérifiez votre adresse email pour sécuriser votre compte.',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: _sending ? null : _resend,
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32)),
                child: Text(_sending ? 'Envoi...' : 'Renvoyer l\'email',
                    style: const TextStyle(
                        color: AppColors.orange,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ),
              TextButton(
                onPressed: _check,
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32)),
                child: const Text('J\'ai vérifié',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
