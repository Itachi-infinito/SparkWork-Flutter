import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../services/session_service.dart';
import '../../services/theme_service.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final themeNotifier = ref.read(themeProvider.notifier);
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;
    final roleLabel = session.isCandidate ? 'Candidat' : 'Recruteur';

    final bg = Theme.of(context).scaffoldBackgroundColor;
    final surface = Theme.of(context).colorScheme.surface;
    final borderColor = isDark ? const Color(0xFF2E3347) : AppColors.border;
    final textPrimary = isDark ? Colors.white : AppColors.textPrimary;
    final textSecondary = isDark ? const Color(0xFF9CA3AF) : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Paramètres'),
        backgroundColor: surface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Compte',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: textSecondary)),
          const SizedBox(height: 8),
          _SettingsCard(
            surface: surface,
            border: borderColor,
            children: [
              _InfoRow(icon: Icons.person_outline, label: 'Nom', value: session.userName, textPrimary: textPrimary, textSecondary: textSecondary),
              Divider(height: 1, color: borderColor),
              _InfoRow(icon: Icons.email_outlined, label: 'Email', value: session.userEmail, textPrimary: textPrimary, textSecondary: textSecondary),
              Divider(height: 1, color: borderColor),
              _InfoRow(icon: Icons.badge_outlined, label: 'Rôle', value: roleLabel, textPrimary: textPrimary, textSecondary: textSecondary),
            ],
          ),
          const SizedBox(height: 24),
          Text('Application',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: textSecondary)),
          const SizedBox(height: 8),
          _SettingsCard(
            surface: surface,
            border: borderColor,
            children: [
              _ToggleRow(
                icon: Icons.dark_mode_outlined,
                label: 'Mode sombre',
                value: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onChanged: (_) => themeNotifier.toggle(),
              ),
            ],
          ),
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
          Center(
            child: Text('SparkWork v1.0.0',
                style: TextStyle(color: textSecondary, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  final Color surface;
  final Color border;
  const _SettingsCard({required this.children, required this.surface, required this.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color textPrimary;
  final Color textSecondary;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: textSecondary, size: 20),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(color: textSecondary, fontSize: 14)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  color: textPrimary,
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
  final Color textPrimary;
  final Color textSecondary;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.textPrimary,
    required this.textSecondary,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: TextStyle(color: textPrimary, fontSize: 14)),
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
