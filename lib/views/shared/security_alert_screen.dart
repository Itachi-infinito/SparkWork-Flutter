import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../models/active_session.dart';
import '../../services/auth_service.dart';
import '../../services/session_security_service.dart';
import '../../services/session_service.dart';

/// Flow de sécurisation en 3 étapes, déclenché quand l'utilisateur tape
/// "Non, sécuriser mon compte" sur une notification d'anomalie.
class SecurityAlertScreen extends ConsumerStatefulWidget {
  const SecurityAlertScreen({super.key});

  @override
  ConsumerState<SecurityAlertScreen> createState() => _SecurityAlertScreenState();
}

class _SecurityAlertScreenState extends ConsumerState<SecurityAlertScreen> {
  int _step = 0;
  List<ActiveSession> _sessions = [];
  bool _loading = true;
  bool _terminatedOthers = false;

  final _currentPwd = TextEditingController();
  final _newPwd = TextEditingController();
  final _confirmPwd = TextEditingController();
  String? _pwdError;
  bool _pwdLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final session = ref.read(sessionProvider);
    final sessions =
        await ref.read(sessionSecurityServiceProvider).getRecentSessions(session.userId);
    if (mounted) setState(() { _sessions = sessions; _loading = false; });
  }

  Future<void> _terminateAllOthers() async {
    final session = ref.read(sessionProvider);
    await ref.read(sessionSecurityServiceProvider).terminateAllOtherSessions(session.userId);
    setState(() => _terminatedOthers = true);
  }

  bool _isStrongPassword(String pwd) {
    return pwd.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(pwd) &&
        RegExp(r'[0-9]').hasMatch(pwd) &&
        RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(pwd);
  }

  Future<void> _submitPasswordChange() async {
    if (!_isStrongPassword(_newPwd.text)) {
      setState(() => _pwdError =
          'Minimum 8 caractères, 1 majuscule, 1 chiffre, 1 caractère spécial.');
      return;
    }
    if (_newPwd.text != _confirmPwd.text) {
      setState(() => _pwdError = 'Les mots de passe ne correspondent pas.');
      return;
    }
    setState(() { _pwdLoading = true; _pwdError = null; });
    final (ok, msg) = await ref.read(authServiceProvider).changePassword(
          currentPassword: _currentPwd.text,
          newPassword: _newPwd.text,
        );
    if (!mounted) return;
    if (ok) {
      setState(() { _pwdLoading = false; _step = 2; });
    } else {
      setState(() { _pwdLoading = false; _pwdError = msg; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sécuriser mon compte'),
        automaticallyImplyLeading: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStepIndicator(),
                Expanded(
                  child: switch (_step) {
                    0 => _buildStep1Sessions(),
                    1 => _buildStep2Password(),
                    _ => _buildStep3Confirmation(),
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          final active = i <= _step;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 32, height: 4,
            decoration: BoxDecoration(
              color: active ? AppColors.primary : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStep1Sessions() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Étape 1 — Sessions actives',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Voici les appareils récemment connectés à votre compte. '
            'Déconnectez tous ceux que vous ne reconnaissez pas.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(children: _sessions.map((s) {
              final dateLabel = DateFormat('d MMM, HH:mm', 'fr_FR').format(s.loginAt);
              return ListTile(
                leading: Icon(
                  s.deviceOS.toLowerCase().contains('ios')
                      ? Icons.phone_iphone
                      : Icons.phone_android,
                  color: s.isActive ? AppColors.green : Colors.grey,
                ),
                title: Text(s.deviceModel),
                subtitle: Text('${s.deviceOS} · $dateLabel'),
                trailing: Text(s.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                        color: s.isActive ? AppColors.green : Colors.grey, fontSize: 12)),
              );
            }).toList()),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _terminatedOthers ? null : _terminateAllOthers,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red, minimumSize: const Size(double.infinity, 50)),
              child: Text(
                  _terminatedOthers
                      ? 'Appareils déconnectés ✓'
                      : 'Déconnecter tous les autres appareils',
                  style: const TextStyle(color: Colors.white)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _terminatedOthers ? () => setState(() => _step = 1) : null,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, minimumSize: const Size(double.infinity, 50)),
              child: const Text('Continuer', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Password() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Étape 2 — Nouveau mot de passe',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Par sécurité, choisissez un nouveau mot de passe.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          if (_pwdError != null)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                  color: AppColors.redLight, borderRadius: BorderRadius.circular(10)),
              child: Text(_pwdError!, style: const TextStyle(color: AppColors.red, fontSize: 12)),
            ),
          TextField(
            controller: _currentPwd,
            obscureText: true,
            decoration: const InputDecoration(
                labelText: 'Mot de passe actuel', prefixIcon: Icon(Icons.lock_outline)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newPwd,
            obscureText: true,
            decoration: const InputDecoration(
                labelText: 'Nouveau mot de passe', prefixIcon: Icon(Icons.lock_reset)),
          ),
          const SizedBox(height: 4),
          Text('8 caractères min., 1 majuscule, 1 chiffre, 1 caractère spécial.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmPwd,
            obscureText: true,
            decoration: const InputDecoration(
                labelText: 'Confirmer le nouveau mot de passe',
                prefixIcon: Icon(Icons.lock_reset)),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _pwdLoading ? null : _submitPasswordChange,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, minimumSize: const Size(double.infinity, 50)),
              child: Text(_pwdLoading ? 'En cours...' : 'Modifier le mot de passe',
                  style: const TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Confirmation() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration:
                  BoxDecoration(color: AppColors.greenLight, shape: BoxShape.circle),
              child: const Icon(Icons.verified_user, size: 56, color: AppColors.green),
            ),
            const SizedBox(height: 24),
            const Text('Votre compte est sécurisé.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Tous les autres appareils ont été déconnectés et votre mot de passe a été modifié.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.go('/settings'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, minimumSize: const Size(200, 48)),
              child: const Text('Terminer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
