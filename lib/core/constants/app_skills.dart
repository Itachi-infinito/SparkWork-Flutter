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

  static const List<String> digitalSkills = [
    'Développement web',
    'Développement mobile',
    'JavaScript',
    'Python',
    'Java',
    'SQL / Bases de données',
    'Cloud (AWS/Azure/GCP)',
    'DevOps',
    'Cybersécurité',
    'UX/UI Design',
    'Gestion de projet Agile/Scrum',
    'Data Analysis',
    'Intelligence artificielle / Machine Learning',
    'Réseaux & infrastructure',
    'Support technique / Helpdesk',
    'Testing / QA',
    'SEO / SEA',
    'Product Management',
    'API / Intégrations',
    'Administration systèmes',
  ];

  static const List<String> rhSkills = [
    'Recrutement',
    'Sourcing de candidats',
    'Entretiens de recrutement',
    'Gestion de la paie',
    'Administration du personnel',
    'Droit social',
    'Formation & développement',
    'Gestion des talents',
    'Onboarding',
    'Relations sociales',
    'SIRH (logiciels RH)',
    'Marque employeur',
    'Gestion des conflits',
    'Évaluation de la performance',
    'Diversité & inclusion',
    'Plan de développement des compétences',
    'Négociation',
    'Communication interne',
    'Bien-être au travail',
    'Gestion des carrières',
  ];

  static const List<String> droitSkills = [
    'Droit du travail',
    'Droit des affaires',
    'Droit civil',
    'Droit pénal',
    'Droit fiscal',
    'Droit immobilier',
    'Rédaction juridique',
    'Contentieux',
    'Conseil juridique',
    'Contrats',
    'Compliance / Conformité',
    'RGPD / Protection des données',
    'Propriété intellectuelle',
    'Droit des sociétés',
    'Négociation contractuelle',
    'Veille juridique',
    'Plaidoirie',
    'Médiation',
    'Due diligence',
    'Droit international',
  ];

  static const List<String> commerceSkills = [
    'Prospection commerciale',
    'Négociation commerciale',
    'Vente en magasin',
    'Conseil client',
    'Gestion de la relation client (CRM)',
    'Techniques de vente',
    'Merchandising',
    'Gestion de caisse',
    'Développement de portefeuille clients',
    'Vente en ligne / E-commerce',
    'Animation commerciale',
    'Fidélisation client',
    'Reporting commercial',
    'Objectifs & KPI',
    'Vente B2B',
    'Vente B2C',
    'Gestion des stocks',
    'Techniques de closing',
    'Étude de marché',
    'Présentation produit',
  ];

  static const List<String> btpSkills = [
    'Lecture de plans',
    'Maçonnerie',
    'Électricité bâtiment',
    'Plomberie',
    'Menuiserie',
    'Peinture & finitions',
    "Conduite d'engins",
    'Gestion de chantier',
    'Sécurité sur chantier',
    'Rénovation',
    'Gros œuvre',
    'Second œuvre',
    'Métrage & devis',
    'Coordination de travaux',
    'Isolation thermique',
    'Carrelage',
    'Toiture / Couverture',
    'Soudure',
    'Normes de construction',
    'Chauffage / HVAC',
  ];

  static const List<String> santeSkills = [
    'Soins infirmiers',
    'Aide à la personne',
    'Accompagnement social',
    'Premiers secours',
    'Gestion de la douleur',
    'Hygiène et sécurité sanitaire',
    'Suivi médical',
    "Relation d'aide",
    'Travail en équipe pluridisciplinaire',
    'Éducation thérapeutique',
    'Soins palliatifs',
    'Gériatrie',
    'Pédiatrie',
    'Aide-soignant',
    'Kinésithérapie',
    'Psychologie',
    'Écoute active',
    'Gestion des urgences',
    'Administration de médicaments',
    'Dossier patient',
  ];

  static const List<String> logistiqueSkills = [
    'Gestion des stocks',
    'Préparation de commandes',
    'Conduite de chariot élévateur (CACES)',
    'Permis poids lourd',
    'Planification des livraisons',
    "Gestion d'entrepôt",
    'Supply chain',
    'Inventaire',
    'Manutention',
    'Traçabilité des marchandises',
    'Optimisation des tournées',
    'Douane & import-export',
    'Gestion de flotte',
    'Réception de marchandises',
    'Emballage & conditionnement',
    'Logistique internationale',
    'ERP / WMS',
    'Sécurité routière',
    'Livraison du dernier kilomètre',
    'Gestion des retours',
  ];

  /// Compétences disponibles par secteur (clé = AppSector.id).
  static const Map<String, List<String>> bySector = {
    'horeca': horecaSkills,
    'digital': digitalSkills,
    'rh': rhSkills,
    'droit': droitSkills,
    'commerce': commerceSkills,
    'btp': btpSkills,
    'sante': santeSkills,
    'logistique': logistiqueSkills,
  };

  /// Union des compétences des secteurs donnés (toutes si la liste est vide).
  static List<String> skillsForSectors(List<String> sectorIds) {
    if (sectorIds.isEmpty) return all;
    final result = <String>{};
    for (final id in sectorIds) {
      result.addAll(bySector[id] ?? const []);
    }
    return result.toList();
  }

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
  static List<String> get all =>
      bySector.values.expand((l) => l).toSet().toList();

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