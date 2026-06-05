import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme_ext.dart';
import '../../core/theme/theme_notifier.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final themeNotifier = ref.read(themeNotifierProvider.notifier);
    final isDark = ref.watch(themeNotifierProvider) == ThemeMode.dark;
    final roleLabel = session.isCandidate ? 'Candidat' : 'Recruteur';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Compte',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: context.textSecondaryColor)),
          const SizedBox(height: 8),
          _SettingsCard(children: [
            _InfoRow(icon: Icons.person_outline, label: 'Nom', value: session.userName),
            Divider(height: 1, color: context.borderColor),
            _InfoRow(icon: Icons.email_outlined, label: 'Email', value: session.userEmail),
            Divider(height: 1, color: context.borderColor),
            _InfoRow(icon: Icons.badge_outlined, label: 'Rôle', value: roleLabel),
          ]),
          const SizedBox(height: 24),
          Text('Application',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: context.textSecondaryColor)),
          const SizedBox(height: 8),
          _SettingsCard(children: [
            _ToggleRow(
              icon: Icons.dark_mode_outlined,
              label: 'Mode sombre',
              value: isDark,
              onChanged: (_) => themeNotifier.toggle(),
            ),
          ]),
          const SizedBox(height: 24),
          Text('Sécurité',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: context.textSecondaryColor)),
          const SizedBox(height: 8),
          _SettingsCard(children: [
            _TapRow(
              icon: Icons.lock_outline,
              label: 'Changer le mot de passe',
              onTap: () => _showChangePasswordDialog(context, ref, session.userId),
            ),
          ]),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) context.go('/welcome');
            },
            icon: const Icon(Icons.logout),
            label: const Text('Se déconnecter'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              minimumSize: const Size(double.infinity, 52),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _showDeleteAccountDialog(context, ref, session.userId),
            icon: const Icon(Icons.delete_forever_outlined, color: AppColors.red),
            label: const Text('Supprimer mon compte',
                style: TextStyle(color: AppColors.red)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.red),
              minimumSize: const Size(double.infinity, 52),
            ),
          ),
          const SizedBox(height: 40),
          Center(
            child: Text('SparkWork v1.0.0',
                style: TextStyle(color: context.textHintColor, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref, String userId) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Changer le mot de passe'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentCtrl,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Mot de passe actuel'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newCtrl,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Nouveau mot de passe'),
                validator: (v) =>
                    v == null || v.length < 6 ? 'Min 6 caractères' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmCtrl,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Confirmer'),
                validator: (v) =>
                    v != newCtrl.text ? 'Les mots de passe ne correspondent pas' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final auth = ref.read(authServiceProvider);
              final (ok, err) = await auth.changePassword(
                userId: userId,
                currentPassword: currentCtrl.text,
                newPassword: newCtrl.text,
              );
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(ok ? 'Mot de passe modifié !' : err),
                backgroundColor: ok ? AppColors.green : AppColors.red,
              ));
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref, String userId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le compte'),
        content: const Text(
            'Cette action est irréversible. Toutes vos données seront supprimées.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final auth = ref.read(authServiceProvider);
              await auth.deleteAccount(userId);
              await ref.read(sessionProvider.notifier).logout();
              if (context.mounted) context.go('/welcome');
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF1E1E1E) : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.isDark ? const Color(0xFF3A3A3A) : AppColors.border,
          width: context.isDark ? 1.5 : 1.0,
        ),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: context.textSecondaryColor, size: 20),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(color: context.textSecondaryColor, fontSize: 14)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  color: context.textPrimaryColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 14)),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: context.textSecondaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: TextStyle(color: context.textPrimaryColor, fontSize: 14)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _TapRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _TapRow({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: context.textSecondaryColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(color: context.textPrimaryColor, fontSize: 14)),
            ),
            Icon(Icons.chevron_right, color: context.textHintColor),
          ],
        ),
      ),
    );
  }
}