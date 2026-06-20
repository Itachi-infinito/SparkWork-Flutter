import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/recommendation.dart';
import '../../services/recommendation_service.dart';

/// Badge "X recommandation(s)" affiché si le candidat a au moins une
/// recommandation publiée. Tap → bottom sheet avec le détail complet.
/// N'affiche rien si aucune recommandation publiée.
class RecommendationCountBadge extends ConsumerWidget {
  final String candidateId;
  final bool light; // true = texte clair (fond sombre des cartes de swipe)
  const RecommendationCountBadge({super.key, required this.candidateId, this.light = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Recommendation>>(
      future: ref.read(recommendationServiceProvider).getPublishedRecommendations(candidateId),
      builder: (context, snapshot) {
        final recs = snapshot.data ?? [];
        if (recs.isEmpty) return const SizedBox();
        return GestureDetector(
          onTap: () => _showRecommendationsSheet(context, recs),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: light ? Colors.white.withOpacity(0.15) : Colors.amber.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: light ? Colors.white.withOpacity(0.3) : Colors.amber.withOpacity(0.4)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.star, size: 13, color: light ? Colors.amber : Colors.amber.shade700),
              const SizedBox(width: 5),
              Text(
                '${recs.length} recommandation${recs.length > 1 ? 's' : ''}',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: light ? Colors.white : Colors.amber.shade800),
              ),
            ]),
          ),
        );
      },
    );
  }

  void _showRecommendationsSheet(BuildContext context, List<Recommendation> recs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text('Recommandations (${recs.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...recs.map((r) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(r.authorName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                      ]),
                      Text('${r.authorRole} · ${r.authorCompany}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      const SizedBox(height: 8),
                      Text(r.text, style: const TextStyle(fontSize: 13, height: 1.5)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
