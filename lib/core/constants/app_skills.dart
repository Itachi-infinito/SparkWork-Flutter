class AppSkills {
  static const List<String> horecaSkills = [
    'Accueil client',
    'Service en salle',
    'Prise de commande',
    'Encaissement',
    'Gestion des réservations',
    'Mise en place',
    'Nettoyage de salle',
    'Service au bar',
    'Préparation de boissons',
    'Connaissance des vins',
    'Cuisine chaude',
    'Cuisine froide',
    'Préparation des desserts',
    'Dressage des assiettes',
    'Plonge',
    'Respect des normes HACCP',
    'Gestion du stress',
    'Travail en équipe',
    'Ponctualité',
    'Flexibilité horaire',
    'Service rapide',
    'Relation client',
    'Gestion des stocks',
    'Réception de marchandises',
    "Organisation d'événements",
  ];

  static const List<String> contractTypes = [
    'CDI',
    'CDD',
    'Intérim',
    'Stage',
    'Alternance',
    'Freelance',
    'Temps partiel',
  ];

  static const List<String> levels = [
    'Débutant',
    'Junior',
    'Confirmé',
    'Senior',
    'Expert',
  ];

  static const List<String> remoteModes = [
    'Présentiel',
    'Télétravail partiel',
    'Télétravail total',
  ];

  static List<String> parseSkills(String value) {
    if (value.isEmpty) return [];
    return value
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static String formatSkills(List<String> skills) {
    return skills.where((s) => s.isNotEmpty).join(', ');
  }
}