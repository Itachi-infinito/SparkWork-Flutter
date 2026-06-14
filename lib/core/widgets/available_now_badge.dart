import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Badge "Disponible maintenant" affiché sur les cartes candidat côté recruteur.
class AvailableNowBadge extends StatelessWidget {
  final bool large;
  const AvailableNowBadge({super.key, this.large = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 12 : 8,
        vertical: large ? 5 : 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.green,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.green.withOpacity(0.4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: large ? 7 : 5,
            height: large ? 7 : 5,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: large ? 6 : 4),
          Text(
            'Disponible',
            style: TextStyle(
              color: Colors.white,
              fontSize: large ? 12 : 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
