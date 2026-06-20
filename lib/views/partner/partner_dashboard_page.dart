import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../models/partner.dart';
import '../../services/partner_service.dart';
import '../../services/session_service.dart';

class PartnerDashboardPage extends ConsumerStatefulWidget {
  const PartnerDashboardPage({super.key});

  @override
  ConsumerState<PartnerDashboardPage> createState() => _PartnerDashboardPageState();
}

class _PartnerDashboardPageState extends ConsumerState<PartnerDashboardPage> {
  Partner? _partner;
  List<Referral> _referrals = [];
  Map<String, String> _namesByUserId = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final session = ref.read(sessionProvider);
    final partnerSvc = ref.read(partnerServiceProvider);
    final partner = await partnerSvc.getPartnerById(session.userId);
    List<Referral> referrals = [];
    final names = <String, String>{};
    if (partner != null) {
      referrals = await partnerSvc.getReferrals(session.userId);
      final db = FirebaseFirestore.instance;
      for (final r in referrals.take(10)) {
        final doc = await db.collection('users').doc(r.referredUserId).get();
        names[r.referredUserId] = doc.data()?['fullName'] as String? ?? 'Utilisateur';
      }
    }
    if (mounted) {
      setState(() {
        _partner = partner;
        _referrals = referrals;
        _namesByUserId = names;
        _loading = false;
      });
    }
  }

  void _copyReferralLink() {
    final code = _partner?.referralCode ?? '';
    final link = 'https://sparkwork.app/register?ref=$code';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Lien de parrainage copié.'),
      backgroundColor: AppColors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_partner == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Espace Partenaire')),
        body: const Center(child: Text('Ce compte n\'est pas un compte partenaire.')),
      );
    }

    final partner = _partner!;
    final candidateRefs = _referrals.where((r) => r.referredUserType == 'candidate').length;
    final recruiterRefs = _referrals.where((r) => r.referredUserType == 'recruiter').length;
    final converted = _referrals.where((r) => r.convertedToPaid).length;
    final totalCommission = _referrals.fold<double>(0, (s, r) => s + r.commissionEarned);
    final now = DateTime.now();
    final monthCommission = _referrals
        .where((r) =>
            r.conversionDate != null &&
            DateTime.tryParse(r.conversionDate!)?.month == now.month &&
            DateTime.tryParse(r.conversionDate!)?.year == now.year)
        .fold<double>(0, (s, r) => s + r.commissionEarned);

    return Scaffold(
      appBar: AppBar(title: Text('Espace Partenaire — ${partner.name}')),
      body: RefreshIndicator(
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
              childAspectRatio: 1.5,
              children: [
                _StatCard(label: 'Candidats parrainés', value: '$candidateRefs', color: AppColors.primary),
                _StatCard(label: 'Recruteurs parrainés', value: '$recruiterRefs', color: AppColors.green),
                _StatCard(label: 'Conversions payantes', value: '$converted', color: AppColors.orange),
                _StatCard(
                    label: 'Commissions (total)',
                    value: '${totalCommission.toStringAsFixed(0)}€',
                    color: Colors.amber.shade800),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                const Icon(Icons.euro, color: AppColors.green),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Commissions ce mois-ci : ${monthCommission.toStringAsFixed(0)}€',
                      style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
            const SizedBox(height: 24),
            const Text('Filleuls par mois (6 derniers mois)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(height: 160, child: _MonthlyChart(referrals: _referrals)),
            const SizedBox(height: 24),
            Text('Derniers filleuls (${_referrals.length})',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_referrals.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('Aucun filleul pour le moment.'),
              )
            else
              ..._referrals.take(10).map((r) {
                final date = DateTime.tryParse(r.createdAt);
                final dateLabel = date != null ? '${date.day}/${date.month}/${date.year}' : '';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(children: [
                    Icon(
                      r.referredUserType == 'candidate' ? Icons.person_outline : Icons.business_outlined,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_namesByUserId[r.referredUserId] ?? 'Utilisateur',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text('${r.referredUserType == 'candidate' ? 'Candidat' : 'Recruteur'} · $dateLabel',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    if (r.convertedToPaid)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: AppColors.greenLight, borderRadius: BorderRadius.circular(10)),
                        child: const Text('Converti',
                            style: TextStyle(fontSize: 10, color: AppColors.green, fontWeight: FontWeight.bold)),
                      ),
                  ]),
                );
              }),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _copyReferralLink,
                icon: const Icon(Icons.link, color: Colors.white),
                label: const Text('Copier mon lien de parrainage',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, minimumSize: const Size(double.infinity, 50)),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text('Code : ${partner.referralCode}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

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
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _MonthlyChart extends StatelessWidget {
  final List<Referral> referrals;
  const _MonthlyChart({required this.referrals});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = List.generate(6, (i) => DateTime(now.year, now.month - 5 + i, 1));
    final counts = months.map((m) {
      return referrals.where((r) {
        final d = DateTime.tryParse(r.createdAt);
        return d != null && d.year == m.year && d.month == m.month;
      }).length;
    }).toList();
    final maxY = (counts.isEmpty ? 1 : counts.reduce((a, b) => a > b ? a : b)).toDouble();

    return BarChart(
      BarChartData(
        maxY: maxY < 4 ? 4 : maxY + 1,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= months.length) return const SizedBox();
                const labels = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun', 'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(labels[months[i].month - 1], style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(months.length, (i) => BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: counts[i].toDouble(),
                color: AppColors.primary,
                width: 18,
                borderRadius: BorderRadius.circular(4),
              ),
            ])),
      ),
    );
  }
}
