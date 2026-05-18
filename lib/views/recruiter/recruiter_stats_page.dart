import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../models/job_offer.dart';
import '../../repositories/candidate_job_like_repository.dart';
import '../../repositories/job_offer_repository.dart';
import '../../repositories/match_repository.dart';
import '../../repositories/recruiter_candidate_like_repository.dart';
import '../../services/session_service.dart';

class RecruiterStatsPage extends ConsumerStatefulWidget {
  const RecruiterStatsPage({super.key});

  @override
  ConsumerState<RecruiterStatsPage> createState() => _RecruiterStatsPageState();
}

class _RecruiterStatsPageState extends ConsumerState<RecruiterStatsPage> {
  bool _loading = true;

  int _offersCount = 0;
  int _swipesSent = 0;
  int _likesReceived = 0;
  int _matchesCount = 0;

  List<_OfferStat> _offerStats = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final session = ref.read(sessionProvider);
    final userId = session.userId;

    final offerRepo = ref.read(jobOfferRepositoryProvider);
    final likeRepo = ref.read(recruiterCandidateLikeRepositoryProvider);
    final candidateLikeRepo = ref.read(candidateJobLikeRepositoryProvider);
    final matchRepo = ref.read(matchRepositoryProvider);

    final offers = await offerRepo.getOffersByRecruiter(userId);
    final offerIds = offers.map((o) => o.jobOfferId).toList();

    final swipesSent = await likeRepo.getLikedCandidateIds(userId);
    final likesReceived = await candidateLikeRepo.countLikesForOffers(offerIds);
    final matches = await matchRepo.getMatchesByRecruiter(userId);
    final likeCountPerOffer = await candidateLikeRepo.getLikeCountPerOffer(offerIds);
    final matchCountPerOffer = <int, int>{};
    for (final m in matches) {
      matchCountPerOffer[m.jobOfferId] = (matchCountPerOffer[m.jobOfferId] ?? 0) + 1;
    }

    final stats = offers.map((o) {
      return _OfferStat(
        offer: o,
        likesReceived: likeCountPerOffer[o.jobOfferId] ?? 0,
        matches: matchCountPerOffer[o.jobOfferId] ?? 0,
      );
    }).toList()
      ..sort((a, b) => b.matches.compareTo(a.matches));

    if (mounted) {
      setState(() {
        _offersCount = offers.length;
        _swipesSent = swipesSent.length;
        _likesReceived = likesReceived;
        _matchesCount = matches.length;
        _offerStats = stats;
        _loading = false;
      });
    }
  }

  double get _conversionRate {
    if (_swipesSent == 0) return 0;
    return (_matchesCount / _swipesSent * 100).clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Statistiques'),
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryGrid(),
                    const SizedBox(height: 24),
                    _buildConversionCard(),
                    const SizedBox(height: 24),
                    const Text('Performance par offre',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    if (_offerStats.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('Aucune offre publiée',
                              style: TextStyle(color: AppColors.textSecondary)),
                        ),
                      )
                    else
                      ..._offerStats.map((s) => _OfferStatCard(stat: s)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _StatCard(
          label: 'Offres publiées',
          value: '$_offersCount',
          icon: Icons.work_outline,
          color: AppColors.primary,
        ),
        _StatCard(
          label: 'Candidats swipés',
          value: '$_swipesSent',
          icon: Icons.swipe_outlined,
          color: AppColors.green,
        ),
        _StatCard(
          label: 'Likes reçus',
          value: '$_likesReceived',
          icon: Icons.thumb_up_outlined,
          color: AppColors.orange,
        ),
        _StatCard(
          label: 'Matches',
          value: '$_matchesCount',
          icon: Icons.favorite_outline,
          color: AppColors.red,
        ),
      ],
    );
  }

  Widget _buildConversionCard() {
    final rate = _conversionRate;
    final rateColor = rate >= 30
        ? AppColors.green
        : rate >= 10
            ? AppColors.orange
            : AppColors.red;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Taux de conversion',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              Text('${rate.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: rateColor)),
            ],
          ),
          const SizedBox(height: 4),
          Text('$_matchesCount match${_matchesCount > 1 ? 's' : ''} sur $_swipesSent swipe${_swipesSent > 1 ? 's' : ''}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: rate / 100,
              minHeight: 10,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(rateColor),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _FunnelStep(label: 'Swipés', value: _swipesSent, color: AppColors.primary),
              const _FunnelArrow(),
              _FunnelStep(label: 'Likes reçus', value: _likesReceived, color: AppColors.orange),
              const _FunnelArrow(),
              _FunnelStep(label: 'Matches', value: _matchesCount, color: AppColors.green),
            ],
          ),
        ],
      ),
    );
  }
}

class _OfferStat {
  final JobOffer offer;
  final int likesReceived;
  final int matches;
  _OfferStat({required this.offer, required this.likesReceived, required this.matches});
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
              Text(label,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _OfferStatCard extends StatelessWidget {
  final _OfferStat stat;
  const _OfferStatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    final maxVal = stat.likesReceived > 0 ? stat.likesReceived : 1;
    final matchRatio = stat.matches / maxVal;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stat.offer.title,
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(stat.offer.companyName,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _MiniStat(value: stat.likesReceived, label: 'likes', color: AppColors.orange),
              const SizedBox(width: 12),
              _MiniStat(value: stat.matches, label: 'match', color: AppColors.green),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: matchRatio.clamp(0.0, 1.0),
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.green,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                stat.likesReceived > 0
                    ? '${(stat.matches / stat.likesReceived * 100).toStringAsFixed(0)}%'
                    : '—',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final int value;
  final String label;
  final Color color;
  const _MiniStat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _FunnelStep extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _FunnelStep({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$value', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _FunnelArrow extends StatelessWidget {
  const _FunnelArrow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Icon(Icons.chevron_right, color: AppColors.border, size: 20),
    );
  }
}