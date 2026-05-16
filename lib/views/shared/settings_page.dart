import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../services/session_service.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final roleLabel = session.isCandidate ? 'Candidat' : 'Recruteur';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Paramètres'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Compte',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          _SettingsCard(children: [
            _InfoRow(icon: Icons.person_outline, label: 'Nom', value: session.userName),
            const Divider(height: 1),
            _InfoRow(icon: Icons.email_outlined, label: 'Email', value: session.userEmail),
            const Divider(height: 1),
            _InfoRow(icon: Icons.badge_outlined, label: 'Rôle', value: roleLabel),
          ]),
          const SizedBox(height: 24),
          const Text('Application',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          _SettingsCard(children: [
            _ToggleRow(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
              value: true,
              onChanged: (_) {},
            ),
            const Divider(height: 1),
            _ToggleRow(
              icon: Icons.dark_mode_outlined,
              label: 'Mode sombre',
              value: false,
              onChanged: (_) {},
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
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
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
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 14)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
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
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 14)),
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