import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme_ext.dart';
import '../../models/rating.dart';
import '../../services/rating_service.dart';

class ReviewsListScreen extends ConsumerStatefulWidget {
  final String userId;
  final String displayName;
  const ReviewsListScreen({super.key, required this.userId, required this.displayName});

  @override
  ConsumerState<ReviewsListScreen> createState() => _ReviewsListScreenState();
}

class _ReviewsListScreenState extends ConsumerState<ReviewsListScreen> {
  List<Rating> _ratings = [];
  AverageRating? _average;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = ref.read(ratingServiceProvider);
    final ratings = await svc.getRatingsForUser(widget.userId);
    final avg = await svc.getAverageRating(widget.userId);
    if (mounted) setState(() { _ratings = ratings; _average = avg; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Avis sur ${widget.displayName}'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_average != null) _buildAverageCard(),
        const SizedBox(height: 16),
        if (_ratings.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.star_outline, size: 48, color: context.textHintColor),
                  const SizedBox(height: 12),
                  Text('Aucun avis pour l\'instant',
                      style: TextStyle(fontSize: 15, color: context.textSecondaryColor)),
                ],
              ),
            ),
          )
        else
          ..._ratings.map((r) => _RatingCard(rating: r)),
      ],
    );
  }

  Widget _buildAverageCard() {
    final avg = _average!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(avg.averageScore.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('sur 5.0',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StarRow(score: avg.averageScore),
                const SizedBox(height: 6),
                Text('${avg.totalReviews} avis',
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingCard extends StatelessWidget {
  final Rating rating;
  const _RatingCard({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StarRow(score: rating.score.toDouble()),
              Text(
                _formatDate(rating.createdAt),
                style: TextStyle(fontSize: 11, color: context.textSecondaryColor),
              ),
            ],
          ),
          if (rating.comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('"${rating.comment}"',
                style: TextStyle(
                    fontSize: 13,
                    color: context.textSecondaryColor,
                    fontStyle: FontStyle.italic,
                    height: 1.5)),
          ],
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return '';
    }
  }
}

class _StarRow extends StatelessWidget {
  final double score;
  const _StarRow({required this.score});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = (i + 1) <= score;
        final half = !filled && (i + 0.5) <= score;
        return Icon(
          half ? Icons.star_half_rounded : (filled ? Icons.star_rounded : Icons.star_outline_rounded),
          size: 18,
          color: const Color(0xFFFBBF24),
        );
      }),
    );
  }
}
