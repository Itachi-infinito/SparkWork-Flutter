import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme_ext.dart';
import '../../repositories/job_offer_repository.dart';
import '../../repositories/match_repository.dart';
import '../../repositories/recruiter_candidate_like_repository.dart';
import '../../services/session_service.dart';
import '../shared/nav_bar.dart';

class RecruiterStatsPage extends ConsumerStatefulWidget {
  const RecruiterStatsPage({super.key});

  @override
  ConsumerState<RecruiterStatsPage> createState() => _RecruiterStatsPageState();
}

class _RecruiterStatsPageState extends ConsumerState<RecruiterStatsPage> {
  bool _loading = true;
  int _totalOffers = 0;
  int _totalLikesGiven = 0;
  int _totalMatches = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final userId = ref.read(sessionProvider).userId;

    final myOffers = await ref
        .read(jobOfferRepositoryProvider)
        .getOffersByRecruiter(userId);

    final likedIds = await ref
        .read(recruiterCandidateLikeRepositoryProvider)
        .getLikedCandidateIds(userId);

    final matches = await ref
        .read(matchRepositoryProvider)
        .getMatchesByRecruiter(userId);

    if (mounted) {
      setState(() {
        _totalOffers = myOffers.length;
        _totalLikesGiven = likedIds.length;
        _totalMatches = matches.length;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final matchRate = _totalLikesGiven > 0
        ? ((_totalMatches / _totalLikesGiven) * 100).round()
        : 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Statistiques'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.orange,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.4,
                      children: [
                        _StatCard(
                          label: 'Offres publiées',
                          value: '$_totalOffers',
                          icon: Icons.work_outline,
                          color: AppColors.primary,
                        ),
                        _StatCard(
                          label: 'Candidats likés',
                          value: '$_totalLikesGiven',
                          icon: Icons.thumb_up_outlined,
                          color: AppColors.orange,
                        ),
                        _StatCard(
                          label: 'Matches',
                          value: '$_totalMatches',
                          icon: Icons.favorite,
                          color: AppColors.green,
                        ),
                        _StatCard(
                          label: 'Taux de match',
                          value: '$matchRate%',
                          icon: Icons.trending_up,
                          color: const Color(0xFF8B5CF6),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (_totalLikesGiven > 0) ...[
                      Text(
                        'Entonnoir de recrutement',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildChart(matchRate),
                      const SizedBox(height: 24),
                    ],
                    _buildTips(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: const RecruiterNavBar(currentIndex: 4),
    );
  }

  Widget _buildChart(int matchRate) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Likes → Matches',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final labels = ['Likés', 'Matchés'];
                        final i = v.toInt();
                        if (i < 0 || i > 1) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            labels[i],
                            style: TextStyle(
                              fontSize: 11,
                              color: context.textSecondaryColor,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: context.borderColor, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(x: 0, barRods: [
                    BarChartRodData(
                      toY: 100,
                      color: AppColors.orange,
                      width: 44,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ]),
                  BarChartGroupData(x: 1, barRods: [
                    BarChartRodData(
                      toY: matchRate.toDouble(),
                      color: AppColors.green,
                      width: 44,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Legend(color: AppColors.orange, label: 'Candidats likés'),
              const SizedBox(width: 20),
              _Legend(color: AppColors.green, label: 'Taux de match ($matchRate%)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTips() {
    final tips = <(String, IconData, Color)>[
      if (_totalOffers == 0)
        ('Publiez votre première offre pour commencer.', Icons.add_circle_outline, AppColors.orange)
      else if (_totalMatches == 0)
        ('Continuez à swiper pour obtenir vos premiers matches !', Icons.swipe, AppColors.primary)
      else
        ('Excellent ! Vous avez $_totalMatches match${_totalMatches > 1 ? 'es' : ''}.', Icons.check_circle_outline, AppColors.green),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Conseils',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimaryColor),
        ),
        const SizedBox(height: 12),
        ...tips.map((t) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(children: [
            Icon(t.$2, color: t.$3, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(t.$1, style: TextStyle(fontSize: 13, color: context.textPrimaryColor)),
            ),
          ]),
        )),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: TextStyle(fontSize: 11, color: context.textSecondaryColor)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: context.textSecondaryColor)),
    ],
  );
}
