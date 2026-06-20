import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../models/active_session.dart';
import '../../services/device_info_service.dart';
import '../../services/session_security_service.dart';
import '../../services/session_service.dart';

/// Accessible depuis Settings → Sécurité → "Gérer mes sessions actives".
class SecuritySessionsPage extends ConsumerStatefulWidget {
  const SecuritySessionsPage({super.key});

  @override
  ConsumerState<SecuritySessionsPage> createState() => _SecuritySessionsPageState();
}

class _SecuritySessionsPageState extends ConsumerState<SecuritySessionsPage> {
  List<ActiveSession> _sessions = [];
  String? _currentDeviceId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final session = ref.read(sessionProvider);
    final deviceId = await ref.read(deviceInfoServiceProvider).getDeviceId();
    final sessions =
        await ref.read(sessionSecurityServiceProvider).getRecentSessions(session.userId);
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _currentDeviceId = deviceId;
        _loading = false;
      });
    }
  }

  Future<void> _terminate(ActiveSession s) async {
    await ref.read(sessionSecurityServiceProvider).terminateSession(s.sessionId);
    _load();
  }

  Future<void> _terminateAllOthers() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnecter tous les autres appareils'),
        content: const Text(
            'Tous les autres appareils connectés à votre compte seront déconnectés immédiatement.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Déconnecter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final session = ref.read(sessionProvider);
    await ref.read(sessionSecurityServiceProvider).terminateAllOtherSessions(session.userId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Tous les autres appareils ont été déconnectés.'),
        backgroundColor: AppColors.green,
      ));
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sessions actives')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Liste des connexions des 30 derniers jours. Ville approximative '
                    'uniquement — votre adresse IP complète n\'est jamais affichée.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  if (_sessions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: Text('Aucune session enregistrée.')),
                    )
                  else
                    ..._sessions.map((s) => _SessionTile(
                          session: s,
                          isCurrentDevice: s.deviceId == _currentDeviceId,
                          onTerminate: s.isActive && s.deviceId != _currentDeviceId
                              ? () => _terminate(s)
                              : null,
                        )),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _terminateAllOthers,
                      icon: const Icon(Icons.logout, color: AppColors.red),
                      label: const Text('Déconnecter tous les autres appareils',
                          style: TextStyle(color: AppColors.red)),
                      style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.red),
                          minimumSize: const Size(double.infinity, 50)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final ActiveSession session;
  final bool isCurrentDevice;
  final VoidCallback? onTerminate;

  const _SessionTile({
    required this.session,
    required this.isCurrentDevice,
    this.onTerminate,
  });

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('d MMM yyyy à HH:mm', 'fr_FR').format(session.loginAt);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: session.isActive ? AppColors.green.withOpacity(0.3) : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(
            session.deviceOS.toLowerCase().contains('ios')
                ? Icons.phone_iphone
                : Icons.phone_android,
            color: session.isActive ? AppColors.green : Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(session.deviceModel,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  if (isCurrentDevice) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                          color: AppColors.primaryLight, borderRadius: BorderRadius.circular(6)),
                      child: const Text('Cet appareil',
                          style: TextStyle(fontSize: 9, color: AppColors.primary)),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                Text('${session.deviceOS} · $dateLabel',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                Text(session.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                        fontSize: 11,
                        color: session.isActive ? AppColors.green : Colors.grey,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (onTerminate != null)
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.red, size: 18),
              onPressed: onTerminate,
            ),
        ],
      ),
    );
  }
}
