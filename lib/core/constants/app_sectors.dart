import 'package:flutter/material.dart';

/// Un secteur d'activité proposé au choix avant l'inscription — détermine
/// les compétences affichées et sert de filtre optionnel au matching.
class AppSector {
  final String id;
  final String label;
  final IconData icon;

  const AppSector(this.id, this.label, this.icon);
}

class AppSectors {
  static const horeca = AppSector('horeca', 'Horeca', Icons.restaurant_outlined);
  static const digital = AppSector('digital', 'Digital & IT', Icons.computer_outlined);
  static const rh = AppSector('rh', 'Ressources Humaines', Icons.groups_outlined);
  static const droit = AppSector('droit', 'Droit & Juridique', Icons.gavel_outlined);
  static const commerce = AppSector('commerce', 'Commerce & Vente', Icons.storefront_outlined);
  static const btp = AppSector('btp', 'Construction & BTP', Icons.construction_outlined);
  static const sante = AppSector('sante', 'Santé & Social', Icons.favorite_outline);
  static const logistique = AppSector('logistique', 'Logistique & Transport', Icons.local_shipping_outlined);

  static const List<AppSector> all = [
    horeca,
    digital,
    rh,
    droit,
    commerce,
    btp,
    sante,
    logistique,
  ];

  static String labelFor(String id) {
    for (final s in all) {
      if (s.id == id) return s.label;
    }
    return id;
  }

  static List<String> labelsFor(List<String> ids) =>
      ids.map(labelFor).toList();
}
