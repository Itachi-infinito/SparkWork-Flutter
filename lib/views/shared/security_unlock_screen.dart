import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../services/session_security_service.dart';

/// Déblocage du mode restreint (anti-partage de compte) par code à 6
/// chiffres envoyé par email à l'adresse du compte.
class SecurityUnlockScreen extends ConsumerStatefulWidget {
  const SecurityUnlockScreen({super.key});

  @override
  ConsumerState<SecurityUnlockScreen> createState() => _SecurityUnlockScreenState();
}

class _SecurityUnlockScreenState extends ConsumerState<SecurityUnlockScreen> {
  bool _codeSent = false;
  bool _loading = false;
  String? _error;
  final _codeCtrl = TextEditingController();

  Future<void> _requestCode() async {
    setState(() { _loading = true; _error = null; });
    try {
      final devCode = await ref.read(sessionSecurityServiceProvider).requestUnlockOtp();
      if (!mounted) return;
      setState(() { _codeSent = true; _loading = false; });
      // TODO: l'envoi d'email réel n'est pas encore branché — le code est
      // affiché ici temporairement pour permettre les tests de bout en bout.
      if (devCode != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Code de test (dev uniquement) : $devCode'),
          duration: const Duration(seconds: 10),
        ));
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'Erreur lors de l\'envoi du code.'; });
    }
  }

  Future<void> _verifyCode() async {
    if (_codeCtrl.text.trim().length != 6) {
      setState(() => _error = 'Le code doit contenir 6 chiffres.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final ok = await ref
          .read(sessionSecurityServiceProvider)
          .verifyUnlockOtp(_codeCtrl.text.trim());
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Compte débloqué !'),
          backgroundColor: AppColors.green,
        ));
        context.go('/settings');
      } else {
        setState(() { _loading = false; _error = 'Code incorrect ou expiré.'; });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'Code incorrect ou expiré.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Débloquer mon compte')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.redLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Pour protéger votre compte, nous avons temporairement limité '
                'certaines fonctionnalités. Une vérification rapide suffit pour tout restaurer.',
                style: TextStyle(color: AppColors.red, fontSize: 13, height: 1.5),
              ),
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: AppColors.redLight, borderRadius: BorderRadius.circular(10)),
                child: Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 12)),
              ),
            if (!_codeSent)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _requestCode,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary, minimumSize: const Size(double.infinity, 50)),
                  child: Text(_loading ? 'Envoi...' : 'Recevoir un code de déblocage',
                      style: const TextStyle(color: Colors.white)),
                ),
              )
            else ...[
              const Text('Entrez le code à 6 chiffres reçu par email :'),
              const SizedBox(height: 12),
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                    hintText: '000000', prefixIcon: Icon(Icons.pin_outlined)),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _verifyCode,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green, minimumSize: const Size(double.infinity, 50)),
                  child: Text(_loading ? 'Vérification...' : 'Vérifier et débloquer',
                      style: const TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loading ? null : _requestCode,
                child: const Text('Renvoyer le code'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
