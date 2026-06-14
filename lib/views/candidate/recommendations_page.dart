import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme_ext.dart';
import '../../models/recommendation.dart';
import '../../services/recommendation_service.dart';
import '../../services/session_service.dart';

class RecommendationsPage extends ConsumerStatefulWidget {
  const RecommendationsPage({super.key});

  @override
  ConsumerState<RecommendationsPage> createState() => _RecommendationsPageState();
}

class _RecommendationsPageState extends ConsumerState<RecommendationsPage> {
  List<Recommendation> _published = [];
  List<Recommendation> _pending = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = ref.read(sessionProvider).userId;
    final svc = ref.read(recommendationServiceProvider);
    final published = await svc.getPublishedRecommendations(userId);
    final pending = await svc.getPendingRecommendations(userId);
    if (mounted) setState(() { _published = published; _pending = pending; _loading = false; });
  }

  Future<void> _requestNew() async {
    try {
      final userId = ref.read(sessionProvider).userId;
      final svc = ref.read(recommendationServiceProvider);
      final token = await svc.requestRecommendation(userId);
      final link = 'https://sparkwork.app/recommend/$token';
      if (mounted) {
        _showLinkSheet(link);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')),
              backgroundColor: AppColors.red),
        );
      }
    }
  }

  void _showLinkSheet(String link) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link, color: AppColors.primary, size: 40),
            const SizedBox(height: 12),
            const Text('Lien de recommandation créé',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Partagez ce lien avec la personne qui souhaite vous recommander.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(link,
                  style: const TextStyle(fontSize: 12, color: AppColors.primary, fontFamily: 'monospace'),
                  textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: link));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lien copié !'), backgroundColor: AppColors.green),
                  );
                  Navigator.pop(ctx);
                },
                icon: const Icon(Icons.copy, color: Colors.white),
                label: const Text('Copier le lien', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recommandations'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        actions: [
          if (_published.length < RecommendationService.maxPublished)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _requestNew,
              tooltip: 'Demander une recommandation',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: _buildBody(),
            ),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildQuota(),
        if (_published.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Publiées (${_published.length})',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: context.textPrimaryColor)),
          const SizedBox(height: 12),
          ..._published.map((r) => _RecommendationCard(rec: r, isPublished: true)),
        ],
        if (_pending.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('En attente (${_pending.length})',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: context.textPrimaryColor)),
          const SizedBox(height: 12),
          ..._pending.map((r) => _RecommendationCard(rec: r, isPublished: false)),
        ],
        if (_published.isEmpty && _pending.isEmpty) ...[
          const SizedBox(height: 60),
          Center(
            child: Column(
              children: [
                Icon(Icons.thumb_up_outlined, size: 64, color: context.textHintColor),
                const SizedBox(height: 16),
                Text('Aucune recommandation',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimaryColor)),
                const SizedBox(height: 8),
                Text('Demandez des recommandations à d\'anciens collègues ou managers.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.textSecondaryColor)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _requestNew,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Demander une recommandation', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildQuota() {
    final count = _published.length;
    final max = RecommendationService.maxPublished;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$count / $max recommandations publiées',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimaryColor)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: count / max,
                    backgroundColor: context.borderColor,
                    color: count >= max ? AppColors.orange : AppColors.primary,
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          if (count < max) ...[
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _requestNew,
              icon: const Icon(Icons.add, color: Colors.white, size: 16),
              label: const Text('Demander', style: TextStyle(color: Colors.white, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final Recommendation rec;
  final bool isPublished;
  const _RecommendationCard({required this.rec, required this.isPublished});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPublished
              ? AppColors.primary.withOpacity(0.2)
              : context.borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isPublished ? AppColors.primaryLight : context.borderColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.thumb_up_outlined,
                  size: 16,
                  color: isPublished ? AppColors.primary : context.textSecondaryColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPublished ? rec.authorName : 'En attente de réponse',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: context.textPrimaryColor),
                    ),
                    if (isPublished && rec.authorRole.isNotEmpty)
                      Text('${rec.authorRole} — ${rec.authorCompany}',
                          style: TextStyle(fontSize: 12, color: context.textSecondaryColor)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPublished ? AppColors.greenLight : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isPublished ? 'Publiée' : 'En attente',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isPublished ? AppColors.green : AppColors.primary),
                ),
              ),
            ],
          ),
          if (isPublished && rec.text.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text('"${rec.text}"',
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
}
