import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme_ext.dart';
import '../../models/insight_report.dart';
import '../../services/insight_service.dart';
import '../../services/session_service.dart';

class InsightsPage extends ConsumerStatefulWidget {
  const InsightsPage({super.key});

  @override
  ConsumerState<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends ConsumerState<InsightsPage> {
  InsightReport? _report;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final userId = ref.read(sessionProvider).userId;
      final svc = ref.read(insightServiceProvider);
      final report = await svc.getLatestReport(userId);
      if (mounted) setState(() { _report = report; _loading = false; });
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights marché'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _buildError()
              : _report == null
                  ? _buildEmpty()
                  : _buildReport(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: AppColors.orange),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.push('/recruiter/plans'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Passer au plan Pro', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_outlined, size: 64, color: context.textHintColor),
            const SizedBox(height: 16),
            Text('Pas encore de rapport',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimaryColor)),
            const SizedBox(height: 8),
            Text('Les insights marché sont générés mensuellement. Revenez en début de mois.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textSecondaryColor, height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildReport() {
    final r = _report!;
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildHeader(r),
          const SizedBox(height: 20),
          _buildKpis(r),
          const SizedBox(height: 20),
          if (r.averageSalaryByRole.isNotEmpty) ...[
            _SectionTitle('Salaires moyens par rôle'),
            const SizedBox(height: 12),
            _buildSalaryChart(r),
          ],
          if (r.mostSearchedSkills.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionTitle('Compétences les plus recherchées'),
            const SizedBox(height: 12),
            _buildSkillsCloud(r),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeader(InsightReport r) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.insights, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            const Text('Rapport mensuel',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
          const SizedBox(height: 6),
          Text(r.periodLabel,
              style: const TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Secteur: ${r.sector} — ${r.region}',
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildKpis(InsightReport r) {
    return Row(children: [
      Expanded(child: _KpiCard(
        icon: Icons.people_outline,
        label: 'Profils actifs',
        value: '${r.totalActiveProfiles}',
        color: AppColors.green,
      )),
      const SizedBox(width: 10),
      Expanded(child: _KpiCard(
        icon: Icons.timer_outlined,
        label: 'Temps match moy.',
        value: '${r.averageMatchTimeHours.toStringAsFixed(0)}h',
        color: AppColors.orange,
      )),
    ]);
  }

  Widget _buildSalaryChart(InsightReport r) {
    final entries = r.averageSalaryByRole.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxSalary = entries.isEmpty ? 1.0 : entries.first.value;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        children: entries.take(8).map((e) {
          final pct = maxSalary > 0 ? e.value / maxSalary : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(e.key,
                          style: TextStyle(fontSize: 12, color: context.textPrimaryColor),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text('${e.value.toStringAsFixed(0)} €',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: context.borderColor,
                    color: AppColors.primary,
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSkillsCloud(InsightReport r) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: r.mostSearchedSkills.asMap().entries.map((e) {
        final index = e.key;
        final skill = e.value;
        final opacity = 1.0 - (index / r.mostSearchedSkills.length) * 0.6;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(opacity * 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withOpacity(opacity * 0.4)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (index < 3) ...[
              Text('${index + 1}', style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary.withOpacity(opacity))),
              const SizedBox(width: 4),
            ],
            Text(skill,
                style: TextStyle(
                    fontSize: 12 + (2 - index.clamp(0, 2)).toDouble(),
                    color: AppColors.primary.withOpacity(opacity),
                    fontWeight: index < 3 ? FontWeight.bold : FontWeight.w500)),
          ]),
        );
      }).toList(),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.bold, color: context.textPrimaryColor));
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _KpiCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: context.textPrimaryColor)),
          Text(label,
              style: TextStyle(fontSize: 11, color: context.textSecondaryColor)),
        ],
      ),
    );
  }
}
