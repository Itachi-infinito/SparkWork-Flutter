import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Badge FOMO — « X recruteurs cette semaine » sur une carte candidat.
///
/// Lit `candidate_analytics/{candidateId}` (déjà calculé quotidiennement par
/// calculateCandidateAnalytics, cf. functions/src/analytics) : aucun calcul
/// côté client, juste un affichage. N'affiche rien si la donnée est absente
/// ou si personne n'a liké cette semaine — un badge à zéro serait contre-
/// productif (donne l'impression que le candidat n'intéresse personne).
class SocialProofBadge extends StatelessWidget {
  final String candidateId;
  final bool light; // true = fond sombre des cartes de swipe
  const SocialProofBadge({super.key, required this.candidateId, this.light = false});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('candidate_analytics')
          .doc(candidateId)
          .get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final count = data?['recruitersThisWeek'] as int? ?? 0;
        if (count <= 0) return const SizedBox();
        final isHot = data?['isHighlyDemanded'] as bool? ?? false;

        final color = isHot ? Colors.orange : (light ? Colors.white : AppColors.primary);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: light ? Colors.white.withOpacity(0.15) : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(light ? 0.3 : 0.35)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(isHot ? Icons.local_fire_department : Icons.visibility_outlined,
                size: 13, color: light ? Colors.white : color),
            const SizedBox(width: 5),
            Text(
              isHot
                  ? 'Très demandé · $count recruteur${count > 1 ? 's' : ''}'
                  : '$count recruteur${count > 1 ? 's' : ''} cette semaine',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: light ? Colors.white : color),
            ),
          ]),
        );
      },
    );
  }
}
