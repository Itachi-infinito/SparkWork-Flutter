import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_sectors.dart';
import '../constants/app_theme_ext.dart';

/// Sélecteur multi-choix des secteurs d'activité (Horeca, Digital, RH...),
/// sous forme de cartes avec icône. Utilisé à l'inscription (avant de
/// choisir ses compétences) et en édition de profil.
class SectorSelector extends StatelessWidget {
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  const SectorSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: AppSectors.all.map((sector) {
        final isSelected = selected.contains(sector.id);
        return _SectorCard(
          sector: sector,
          isSelected: isSelected,
          onTap: () {
            final updated = List<String>.from(selected);
            isSelected ? updated.remove(sector.id) : updated.add(sector.id);
            onChanged(updated);
          },
        );
      }).toList(),
    );
  }
}

class _SectorCard extends StatelessWidget {
  final AppSector sector;
  final bool isSelected;
  final VoidCallback onTap;

  const _SectorCard({
    required this.sector,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : context.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : context.borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(sector.icon,
                    size: 26,
                    color: isSelected
                        ? AppColors.primary
                        : context.textSecondaryColor),
                const SizedBox(height: 10),
                Text(sector.label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? AppColors.primary
                            : context.textPrimaryColor)),
              ],
            ),
            if (isSelected)
              const Positioned(
                top: 0,
                right: 0,
                child: Icon(Icons.check_circle,
                    color: AppColors.primary, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}
