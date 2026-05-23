import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_notifier.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
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
          const _SectionLabel('Compte'),
          _SettingsCard(children: [
            _InfoRow(
                icon: Icons.person_outline,
                label: 'Nom',
                value: session.userName),
            const Divider(height: 1),
            _InfoRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: session.userEmail),
            const Divider(height: 1),
            _InfoRow(
                icon: Icons.badge_outlined,
                label: 'Rôle',
                value: roleLabel),
          ]),
          const SizedBox(height: 20),
          const _SectionLabel('Apparence'),
          _SettingsCard(children: [
            _ToggleRow(
              icon: isDark
                  ? Icons.dark_mode_rounded
                  : Icons.light_mode_rounded,
              label: 'Mode sombre',
              value: isDark,
              onChanged: (_) =>
                  ref.read(themeNotifierProvider.notifier).toggle(),
            ),
          ]),
          const SizedBox(height: 20),
          const _SectionLabel('Sécurité'),
          _SettingsCard(children: [
            _ActionRow(
              icon: Icons.lock_outline,
              label: 'Changer le mot de passe',
              onTap: () => _showChangePasswordDialog(context, ref),
            ),
          ]),
          const SizedBox(height: 20),
          const _SectionLabel('Danger'),
          _SettingsCard(children: [
            _ActionRow(
              icon: Icons.delete_outline,
              label: 'Supprimer mon compte',
              color: AppColors.red,
              onTap: () => _showDeleteAccountDialog(context, ref),
            ),
          ]),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () async {
              await ref.read(sessionProvider.notifier).logout();
              if (context.mounted) context.go('/welcome');
            },
            icon: const Icon(Icons.logout),
            label: const Text('Se déconnecter'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 40),
          const Center(
            child: Text('SparkWork v1.0.0',
                style: TextStyle(color: AppColors.textHint, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Changer le mot de passe'),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Mot de passe actuel', isDense: true),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Nouveau mot de passe', isDense: true),
                validator: (v) => (v == null || v.length < 6)
                    ? 'Au moins 6 caractères'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Confirmer', isDense: true),
                validator: (v) => v != newCtrl.text
                    ? 'Les mots de passe ne correspondent pas'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final session = ref.read(sessionProvider);
              final (ok, error) =
                  await ref.read(authServiceProvider).changePassword(
                        userId: session.userId,
                        currentPassword: currentCtrl.text,
                        newPassword: newCtrl.text,
                      );
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(ok ? 'Mot de passe modifié ✓' : error),
                backgroundColor:
                    ok ? AppColors.green : AppColors.red,
              ));
            },
            child: const Text('Confirmer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le compte'),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const Text(
            'Cette action est irréversible. Toutes vos données seront supprimées définitivement.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () async {
              final session = ref.read(sessionProvider);
              await ref
                  .read(authServiceProvider)
                  .deleteAccount(session.userId);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (context.mounted) context.go('/welcome');
            },
            child: const Text('Supprimer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: Theme.of(context).dividerTheme.color ??
                AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Icon(icon,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withOpacity(0.5),
            size: 20),
        const SizedBox(width: 12),
        Text(label,
            style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.6),
                fontSize: 14)),
        const Spacer(),
        Flexible(
          child: Text(value,
              textAlign: TextAlign.end,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                  fontSize: 14)),
        ),
      ]),
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
      child: Row(children: [
        Icon(icon,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withOpacity(0.5),
            size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 14)),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
        ),
      ]),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.textPrimary,
  });
  @override
  Widget build(BuildContext context) {
    final textColor = color == AppColors.textPrimary
        ? Theme.of(context).colorScheme.onSurface
        : color;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: textColor, fontSize: 14)),
          const Spacer(),
          Icon(Icons.chevron_right,
              color: textColor.withOpacity(0.4), size: 18),
        ]),
      ),
    );
  }
}