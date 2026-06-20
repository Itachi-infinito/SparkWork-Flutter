import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_avatar.dart';

/// Fiche de candidature synthétique générée automatiquement à la création
/// du match (Pro uniquement). Écran natif — export PDF non implémenté.
/// TODO: export PDF
class MatchReportScreen extends StatelessWidget {
  final String matchId;
  const MatchReportScreen({super.key, required this.matchId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rapport de candidature')),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance.collection('match_reports').doc(matchId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!(snapshot.data?.exists ?? false)) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Rapport non disponible — cette fonctionnalité est réservée au plan Pro.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final r = snapshot.data!.data()!;
          final matchingSkills = (r['matchingSkills'] as List?)?.cast<String>() ?? [];
          final otherSkills = (r['otherSkills'] as List?)?.cast<String>() ?? [];
          final sparkScore = r['sparkScore'] as int? ?? 0;
          final verificationStatus = r['verificationStatus'] as String? ?? 'unverified';

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Column(children: [
                  AppAvatar(
                      name: r['candidateName'] as String? ?? '?',
                      radius: 44,
                      photoPath: r['candidatePhotoUrl'] as String?),
                  const SizedBox(height: 12),
                  Text(r['candidateName'] as String? ?? '',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  if ((r['jobTitle'] as String? ?? '').isNotEmpty)
                    Text(r['jobTitle'] as String,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ]),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: _StatChip(
                    icon: Icons.bolt, label: 'SparkScore', value: '$sparkScore%',
                    color: sparkScore > 75 ? AppColors.green : sparkScore >= 50 ? AppColors.orange : AppColors.red)),
                const SizedBox(width: 10),
                Expanded(child: _StatChip(
                    icon: Icons.star, label: 'Note moyenne',
                    value: r['averageRating'] != null
                        ? '${(r['averageRating'] as num).toStringAsFixed(1)}/5 (${r['totalReviews']})'
                        : 'Aucune',
                    color: Colors.amber)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _StatChip(
                    icon: verificationStatus == 'verified' ? Icons.verified_user : Icons.gpp_maybe_outlined,
                    label: 'Vérification',
                    value: verificationStatus == 'verified' ? 'Vérifié' : 'Non vérifié',
                    color: verificationStatus == 'verified' ? const Color(0xFF3B82F6) : Colors.grey)),
                const SizedBox(width: 10),
                Expanded(child: _StatChip(
                    icon: Icons.star_outline,
                    label: 'Recommandations',
                    value: '${r['recommendationCount'] ?? 0}',
                    color: Colors.amber.shade700)),
              ]),
              const SizedBox(height: 10),
              _StatChip(
                  icon: r['isAvailableNow'] == true ? Icons.flash_on : Icons.schedule,
                  label: 'Disponibilité',
                  value: r['isAvailableNow'] == true ? 'Disponible maintenant' : 'À confirmer',
                  color: r['isAvailableNow'] == true ? AppColors.green : Colors.grey,
                  fullWidth: true),
              const SizedBox(height: 24),
              if (matchingSkills.isNotEmpty) ...[
                const Text('Compétences clés (correspondent à l\'offre)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: matchingSkills.map((s) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: AppColors.greenLight, borderRadius: BorderRadius.circular(20)),
                      child: Text(s, style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w600, fontSize: 12)),
                    )).toList()),
                const SizedBox(height: 16),
              ],
              if (otherSkills.isNotEmpty) ...[
                const Text('Autres compétences', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: otherSkills.map((s) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                      child: Text(s, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                    )).toList()),
              ],
              const SizedBox(height: 24),
              Center(
                child: Text('TODO : export PDF — bientôt disponible',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool fullWidth;
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
              Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ]),
    );
  }
}
