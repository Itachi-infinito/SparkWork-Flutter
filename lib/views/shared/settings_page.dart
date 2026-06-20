import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/subscription.dart';
import '../../services/auth_service.dart';
import '../../services/partner_service.dart';
import '../../services/session_security_service.dart';
import '../../services/session_service.dart';
import '../../services/subscription_service.dart';
import '../../services/theme_service.dart';
import '../../services/recruiter_theme_service.dart';
import '../../models/recruiter_theme.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  RecruiterSubscription? _sub;
  bool _isPartner = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSub();
      _checkPartner();
    });
  }

  Future<void> _loadSub() async {
    final session = ref.read(sessionProvider);
    if (!session.isRecruiter) return;
    final sub = await ref
        .read(subscriptionServiceProvider)
        .getSubscription(session.userId);
    if (mounted) setState(() => _sub = sub);
  }

  Future<void> _checkPartner() async {
    final session = ref.read(sessionProvider);
    final partner = await ref.read(partnerServiceProvider).getPartnerById(session.userId);
    if (mounted) setState(() => _isPartner = partner != null);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final themeNotifier = ref.read(themeProvider.notifier);
    // Brightness RÉELLEMENT affichée — pas la préférence brute du toggle :
    // une ambiance colorée (Alpine, Terracotta...) peut forcer le clair ou
    // le sombre indépendamment du toggle (cf. main.dart effectiveThemeMode).
    // Se baser sur le toggle brut désynchronise les couleurs de texte du
    // fond réellement affiché et les rend illisibles.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final recruiterAccent = ref.watch(recruiterThemeProvider);
    final hasAccent = session.isRecruiter && recruiterAccent != null;
    final roleLabel = session.isCandidate ? 'Candidat' : 'Recruteur';

    final bg = Theme.of(context).scaffoldBackgroundColor;
    final surface = Theme.of(context).colorScheme.surface;
    final borderColor = isDark ? const Color(0xFF2E3347) : AppColors.border;
    final textPrimary = isDark ? Colors.white : AppColors.textPrimary;
    final textSecondary =
        isDark ? const Color(0xFF9CA3AF) : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top + 12, 20, 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D0117), Color(0xFF1E0A3C), AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(height: 14),
                const Icon(Icons.settings_outlined, color: Colors.white, size: 28),
                const SizedBox(height: 8),
                const Text('Paramètres',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Text('${session.userName} · $roleLabel',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.72), fontSize: 14)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
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
          if (_isPartner) ...[
            const SizedBox(height: 24),
            Text('Partenaire',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: textSecondary)),
            const SizedBox(height: 8),
            _SettingsCard(
              surface: surface,
              border: borderColor,
              children: [
                _NavRow(
                  icon: Icons.handshake_outlined,
                  label: 'Espace Partenaire',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () => context.push('/partner/dashboard'),
                ),
              ],
            ),
          ],
          if (session.isAdmin) ...[
            const SizedBox(height: 24),
            Text('Administration',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: textSecondary)),
            const SizedBox(height: 8),
            _SettingsCard(
              surface: surface,
              border: borderColor,
              children: [
                _NavRow(
                  icon: Icons.admin_panel_settings_outlined,
                  label: 'Dashboard sécurité',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () => context.push('/admin/security'),
                ),
              ],
            ),
          ],
          if (session.isRecruiter) ...[
            const SizedBox(height: 24),
            Text('Abonnement',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: textSecondary)),
            const SizedBox(height: 8),
            _SettingsCard(
              surface: surface,
              border: borderColor,
              children: [
                _SubRow(
                  sub: _sub,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onManage: () => context.push('/recruiter/plans').then((_) => _loadSub()),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Text('Sécurité',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: textSecondary)),
          const SizedBox(height: 8),
          _SettingsCard(
            surface: surface,
            border: borderColor,
            children: [
              _NavRow(
                icon: Icons.lock_outline,
                label: 'Changer le mot de passe',
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onTap: () => _showChangePasswordDialog(context, ref),
              ),
              Divider(height: 1, color: borderColor),
              _NavRow(
                icon: Icons.devices_outlined,
                label: 'Gérer mes sessions actives',
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onTap: () => context.push('/security/sessions'),
              ),
              Divider(height: 1, color: borderColor),
              _NavRow(
                icon: Icons.history_toggle_off_outlined,
                label: 'Supprimer mes logs de sécurité',
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onTap: () => _deleteSecurityLogs(context, ref),
              ),
              Divider(height: 1, color: borderColor),
              _NavRow(
                icon: Icons.delete_forever_outlined,
                label: 'Supprimer mon compte',
                labelColor: AppColors.red,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onTap: () => _showDeleteAccountDialog(context, ref),
              ),
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
                label: hasAccent ? 'Mode sombre (déterminé par l\'ambiance)' : 'Mode sombre',
                value: isDark,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onChanged: hasAccent ? null : (_) => themeNotifier.toggle(),
              ),
              Divider(height: 1, color: borderColor),
              _NavRow(
                icon: Icons.notifications_outlined,
                label: 'Notifications',
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onTap: () => context.push('/notifications/settings'),
              ),
            ],
          ),
          if (session.isRecruiter) ...[
            const SizedBox(height: 24),
            Text('Apparence',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: textSecondary)),
            const SizedBox(height: 8),
            _SettingsCard(
              surface: surface,
              border: borderColor,
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: _ThemeSelector(
                    plan: _sub?.effectivePlan ?? SubscriptionPlan.free,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Text('Légal',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: textSecondary)),
          const SizedBox(height: 8),
          _SettingsCard(
            surface: surface,
            border: borderColor,
            children: [
              _NavRow(
                icon: Icons.description_outlined,
                label: 'Conditions générales d\'utilisation',
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onTap: () => context.push('/legal/terms'),
              ),
              Divider(height: 1, color: borderColor),
              _NavRow(
                icon: Icons.privacy_tip_outlined,
                label: 'Politique de confidentialité',
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                onTap: () => context.push('/legal/privacy'),
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
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSecurityLogs(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer mes logs de sécurité'),
        content: const Text(
            'Vos historiques de connexions et d\'alertes de sécurité seront supprimés définitivement.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(sessionSecurityServiceProvider).deleteMySecurityLogs();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Logs de sécurité supprimés.'),
        backgroundColor: AppColors.green,
      ));
    }
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? error;
    bool loading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Changer le mot de passe'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                      color: AppColors.redLight,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(error!,
                      style: const TextStyle(
                          color: AppColors.red, fontSize: 12)),
                ),
              TextField(
                controller: currentCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Mot de passe actuel',
                    prefixIcon: Icon(Icons.lock_outline)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Nouveau mot de passe',
                    prefixIcon: Icon(Icons.lock_reset)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Confirmer le nouveau',
                    prefixIcon: Icon(Icons.lock_reset)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (newCtrl.text.length < 6) {
                        setDialog(() =>
                            error = 'Minimum 6 caractères.');
                        return;
                      }
                      if (newCtrl.text != confirmCtrl.text) {
                        setDialog(() => error =
                            'Les mots de passe ne correspondent pas.');
                        return;
                      }
                      setDialog(() { loading = true; error = null; });
                      final (ok, msg) = await ref
                          .read(authServiceProvider)
                          .changePassword(
                            currentPassword: currentCtrl.text,
                            newPassword: newCtrl.text,
                          );
                      if (!ctx.mounted) return;
                      if (ok) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Mot de passe modifié !'),
                                backgroundColor: AppColors.green));
                      } else {
                        setDialog(() { loading = false; error = msg; });
                      }
                    },
              child: Text(loading ? 'En cours...' : 'Modifier'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    final passwordCtrl = TextEditingController();
    String? error;
    bool loading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Supprimer mon compte'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cette action est définitive. Votre profil, vos likes, '
                'vos matches, vos messages et vos offres seront '
                'supprimés.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              if (error != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                      color: AppColors.redLight,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(error!,
                      style: const TextStyle(
                          color: AppColors.red, fontSize: 12)),
                ),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mot de passe (confirmation)',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red),
              onPressed: loading
                  ? null
                  : () async {
                      if (passwordCtrl.text.isEmpty) {
                        setDialog(() =>
                            error = 'Mot de passe requis.');
                        return;
                      }
                      setDialog(() { loading = true; error = null; });
                      final (ok, msg) = await ref
                          .read(authServiceProvider)
                          .deleteAccountFully(
                              password: passwordCtrl.text);
                      if (!ctx.mounted) return;
                      if (ok) {
                        Navigator.pop(ctx);
                        ref.read(sessionProvider.notifier).clear();
                        if (context.mounted) context.go('/welcome');
                      } else {
                        setDialog(() { loading = false; error = msg; });
                      }
                    },
              child: Text(
                  loading ? 'Suppression...' : 'Supprimer définitivement',
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubRow extends StatelessWidget {
  final RecruiterSubscription? sub;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onManage;

  const _SubRow({
    required this.sub,
    required this.textPrimary,
    required this.textSecondary,
    required this.onManage,
  });

  String get _planLabel {
    if (sub == null) return 'Chargement...';
    if (sub!.isTrialActive) {
      return 'Essai Pro — ${sub!.trialDaysRemaining} j restant${sub!.trialDaysRemaining > 1 ? 's' : ''}';
    }
    switch (sub!.effectivePlan) {
      case SubscriptionPlan.free:
        return 'Gratuit';
      case SubscriptionPlan.starter:
        return 'Starter — 49€/mois';
      case SubscriptionPlan.pro:
        return 'Pro — 129€/mois';
    }
  }

  Color get _planColor {
    if (sub == null) return AppColors.textSecondary;
    if (sub!.isTrialActive) return const Color(0xFF8B5CF6);
    switch (sub!.effectivePlan) {
      case SubscriptionPlan.free:
        return AppColors.textSecondary;
      case SubscriptionPlan.starter:
        return AppColors.primary;
      case SubscriptionPlan.pro:
        return const Color(0xFF8B5CF6);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onManage,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.workspace_premium_outlined, color: _planColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mon abonnement',
                      style: TextStyle(color: textPrimary, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(_planLabel,
                      style: TextStyle(
                          color: _planColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: textSecondary, size: 20),
          ],
        ),
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
          Flexible(
            child: Text(value,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? labelColor;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;
  const _NavRow({
    required this.icon,
    required this.label,
    this.labelColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: labelColor ?? textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: labelColor ?? textPrimary, fontSize: 14)),
            ),
            Icon(Icons.chevron_right, color: textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Sélecteur d'ambiance (système de thèmes) — "Classique" (apparence par
/// défaut, aucune ambiance) est toujours disponible. Les 5 préréglages
/// colorés nécessitent Starter ou Pro ; la personnalisation custom est
/// réservée au Pro. Le logo SparkWork ne change jamais quel que soit le
/// thème choisi.
class _ThemeSelector extends ConsumerWidget {
  final SubscriptionPlan plan;
  final Color textPrimary;
  final Color textSecondary;
  const _ThemeSelector({
    required this.plan,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(recruiterThemeProvider);
    final unlocked = plan == SubscriptionPlan.starter || plan == SubscriptionPlan.pro;
    final canCustomize = plan == SubscriptionPlan.pro;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ambiance de votre espace recruteur',
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 4),
        Text('Le logo SparkWork reste inchangé. Visible uniquement par vous.',
            style: TextStyle(color: textSecondary, fontSize: 11)),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _ClassicSwatch(
              selected: current == null,
              onTap: () => ref.read(recruiterThemeProvider.notifier).resetToDefault(),
            ),
            ...RecruiterTheme.presets.map((t) {
              final selected = current?.themeId == t.themeId;
              final locked = !unlocked;
              return _ThemeSwatch(
                theme: t,
                selected: selected,
                locked: locked,
                onTap: () async {
                  if (locked) {
                    context.push('/recruiter/plans');
                    return;
                  }
                  await ref.read(recruiterThemeProvider.notifier).setTheme(t);
                },
              );
            }),
            GestureDetector(
              onTap: () {
                if (!canCustomize) {
                  context.push('/recruiter/plans');
                  return;
                }
                context.push('/recruiter/theme/custom');
              },
              child: Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: current?.themeId == 'custom' ? AppColors.primary : textSecondary.withOpacity(0.3),
                      width: current?.themeId == 'custom' ? 2.5 : 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  canCustomize ? Icons.add : Icons.lock_outline,
                  color: textSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ClassicSwatch extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  const _ClassicSwatch({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppColors.surfaceVariant,
          border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent, width: 2.5),
          boxShadow: selected ? [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 8)] : null,
        ),
        child: Stack(children: [
          const Positioned(
            bottom: 4, left: 0, right: 0,
            child: Text('Classique',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
          if (selected)
            const Positioned(
              top: 4, right: 4,
              child: Icon(Icons.check_circle, color: AppColors.primary, size: 14),
            ),
        ]),
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  final RecruiterTheme theme;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;
  const _ThemeSwatch({
    required this.theme,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [theme.gradientStart, theme.gradientEnd],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          border: Border.all(
              color: selected ? Colors.white : Colors.transparent, width: 2.5),
          boxShadow: selected ? [BoxShadow(color: theme.primaryColor.withOpacity(0.5), blurRadius: 8)] : null,
        ),
        child: Stack(children: [
          if (locked)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.lock_outline, color: Colors.white, size: 18),
              ),
            ),
          Positioned(
            bottom: 4, left: 0, right: 0,
            child: Text(theme.themeName,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
          if (selected && !locked)
            const Positioned(
              top: 4, right: 4,
              child: Icon(Icons.check_circle, color: Colors.white, size: 14),
            ),
        ]),
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
  final ValueChanged<bool>? onChanged;
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
