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
  static List<String> get all => horecaSkills;

  // Migration des anciennes valeurs saisies via une version précédente
  // de l'édition de profil (listes hardcodées divergentes).
  static String normalizeLevel(String value) {
    if (value == 'Intermédiaire') return 'Confirmé';
    return value;
  }

  static String normalizeRemote(String value) {
    // Supporte les valeurs multiples ("Présentiel,Télétravail partiel")
    String normalizeOne(String v) {
      if (v == 'Hybride') return 'Télétravail partiel';
      if (v == 'Télétravail') return 'Télétravail total';
      return v;
    }

    if (!value.contains(',')) return normalizeOne(value.trim());
    return value
        .split(',')
        .map((v) => normalizeOne(v.trim()))
        .where((v) => v.isNotEmpty)
        .join(',');
  }
}