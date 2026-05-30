import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_theme_ext.dart';
import '../utils/profile_completion.dart';

class ProfileCompletionCard extends StatelessWidget {
  final int score;
  final List<CompletionItem> missing;
  final VoidCallback? onEdit;   // ← ajoute ça

  const ProfileCompletionCard({
    super.key,
    required this.score,
    required this.missing,
    this.onEdit,                // ← ajoute ça
  });

  @override
  Widget build(BuildContext context) {
    final color = ProfileCompletion.color(score);
    final label = ProfileCompletion.label(score);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
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
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: score / 100,
                        minHeight: 8,
                        backgroundColor: color.withOpacity(0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$score%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: color,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (missing.isNotEmpty && score < 90) ...[
            const SizedBox(height: 12),
            Text(
              'À compléter :',
              style: TextStyle(
                fontSize: 12,
                color: context.textSecondaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            ...missing.take(3).map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(item.icon, size: 14, color: color),
                      const SizedBox(width: 8),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onEdit ?? () => context.push('/candidate/profile/edit'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: color),
                  minimumSize: const Size(double.infinity, 38),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Compléter mon profil',
                    style: TextStyle(fontSize: 13)),
              ),
            ),
          ],
          if (score >= 90) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.verified, color: color, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Votre profil est optimisé pour les recruteurs !',
                    style: TextStyle(fontSize: 12, color: color),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}