import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../services/session_service.dart';
import '../../l10n/generated/app_localizations.dart';

/// Dashboard sécurité — accessible uniquement aux comptes `isAdmin: true`.
/// Toutes les métriques sont des heuristiques de détection de partage de
/// compte, jamais des certitudes.
class SecurityDashboardPage extends ConsumerStatefulWidget {
  const SecurityDashboardPage({super.key});

  @override
  ConsumerState<SecurityDashboardPage> createState() => _SecurityDashboardPageState();
}

class _SecurityDashboardPageState extends ConsumerState<SecurityDashboardPage> {
  Map<String, dynamic>? _metrics;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _restrictedUsers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = FirebaseFirestore.instance;
    final dashboardDoc = await db.collection('security_dashboard').doc('latest').get();
    final restrictedSnap =
        await db.collection('users').where('isRestricted', isEqualTo: true).get();
    if (mounted) {
      setState(() {
        _metrics = dashboardDoc.data();
        _restrictedUsers = restrictedSnap.docs;
        _loading = false;
      });
    }
  }

  Future<void> _unlockUser(String userId) async {
    final loc = AppLocalizations.of(context)!;
    final callable =
        FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('adminUnlockRestrictedAccount');
    await callable.call({'userId': userId});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(loc.secDashUnlocked),
        backgroundColor: AppColors.green,
      ));
    }
    _load();
  }

  void _exportRestrictedList() {
    final loc = AppLocalizations.of(context)!;
    final csv = StringBuffer('userId,fullName,email\n');
    for (final doc in _restrictedUsers) {
      final d = doc.data();
      csv.writeln('${doc.id},${d['fullName'] ?? ''},${d['email'] ?? ''}');
    }
    Clipboard.setData(ClipboardData(text: csv.toString()));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(loc.secDashCsvCopied),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final session = ref.watch(sessionProvider);
    if (!session.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: Text(loc.secDashTitle)),
        body: Center(child: Text(loc.secDashAdminOnly)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(loc.secDashTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: [
                      _KpiCard(
                        label: loc.secDashMultiDevice,
                        value: '${_metrics?['totalAccountsWithMultipleDevices'] ?? '—'}',
                        color: AppColors.primary,
                      ),
                      _KpiCard(
                        label: loc.secDashMediumAlerts,
                        value: '${_metrics?['totalMediumFlags'] ?? '—'}',
                        color: AppColors.orange,
                      ),
                      _KpiCard(
                        label: loc.secDashHighAlerts,
                        value: '${_metrics?['totalHighFlags'] ?? '—'}',
                        color: AppColors.red,
                      ),
                      _KpiCard(
                        label: loc.secDashRestrictedAccounts,
                        value: '${_metrics?['totalRestrictedAccounts'] ?? '—'}',
                        color: AppColors.red,
                      ),
                      _KpiCard(
                        label: loc.secDashEstimatedShares,
                        value: '${_metrics?['estimatedSharedAccounts'] ?? '—'}',
                        color: AppColors.orange,
                      ),
                      _KpiCard(
                        label: loc.secDashRevenueLeak,
                        value: '${_metrics?['potentialRevenueLeakMonthly'] ?? '—'}€',
                        color: AppColors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text(loc.secDashRestrictedCount(_restrictedUsers.length),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _restrictedUsers.isEmpty ? null : _exportRestrictedList,
                        icon: const Icon(Icons.download_outlined, size: 16),
                        label: Text(loc.secDashExportCsv),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_restrictedUsers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(loc.secDashNoRestricted),
                    )
                  else
                    ..._restrictedUsers.map((doc) {
                      final d = doc.data();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.red.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(d['fullName'] as String? ?? loc.secDashNoName,
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text(d['email'] as String? ?? '',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => _unlockUser(doc.id),
                              child: Text(loc.secDashUnlockButton),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _KpiCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
