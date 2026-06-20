import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';

/// Upsell vers la Gestion d'équipe Pro — jamais punitif, toujours formulé
/// comme une solution. Deux variantes : douce (dismissible librement,
/// re-proposée au plus 1x/semaine) et forte (après confirmation d'une
/// anomalie "Oui c'est moi", dismissible 3 jours seulement).
Future<void> showTeamUpsellSheet(BuildContext context, {required bool strong}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.groups_outlined, color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            strong ? 'Vous partagez votre compte ?' : 'Vous recrutez en équipe ?',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            strong
                ? 'Si vous partagez votre compte avec des collègues, la Gestion '
                  'd\'équipe Pro est faite pour vous. Chaque membre a son propre profil sécurisé.'
                : 'Vous êtes plusieurs à recruter dans votre établissement ? La '
                  'Gestion d\'équipe Pro permet à chaque recruteur d\'avoir son '
                  'propre accès. Chacun voit les mêmes candidats et peut laisser ses notes.',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(strong ? 'Plus tard' : 'Non merci'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/recruiter/plans');
                },
                child: Text(strong ? 'Découvrir' : 'En savoir plus',
                    style: const TextStyle(color: Colors.white)),
              ),
            ),
          ]),
        ],
      ),
    ),
  );
}
