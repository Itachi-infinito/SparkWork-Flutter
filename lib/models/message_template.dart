class MessageTemplate {
  final String templateId;
  final String title;
  final String body;
  final String createdAt;
  final int usageCount;

  const MessageTemplate({
    required this.templateId,
    required this.title,
    required this.body,
    required this.createdAt,
    this.usageCount = 0,
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'body': body,
        'createdAt': createdAt,
        'usageCount': usageCount,
      };

  factory MessageTemplate.fromMap(Map<String, dynamic> map, String docId) =>
      MessageTemplate(
        templateId: docId,
        title: map['title'] as String? ?? '',
        body: map['body'] as String? ?? '',
        createdAt: map['createdAt'] as String? ?? '',
        usageCount: (map['usageCount'] as num?)?.toInt() ?? 0,
      );

  static List<MessageTemplate> defaults() {
    final now = DateTime.now().toIso8601String();
    return [
      MessageTemplate(
        templateId: '',
        title: 'Premier contact',
        body: 'Bonjour {prénom_candidat}, votre profil a retenu mon attention pour '
            'notre poste de {poste} à {lieu}. Seriez-vous disponible pour en discuter ?',
        createdAt: now,
      ),
      MessageTemplate(
        templateId: '',
        title: 'Invitation à un entretien',
        body: 'Bonjour {prénom_candidat}, suite à votre candidature pour {poste}, '
            'nous aimerions vous rencontrer. Quelles sont vos disponibilités cette semaine ?',
        createdAt: now,
      ),
      MessageTemplate(
        templateId: '',
        title: 'Refus poli',
        body: 'Bonjour {prénom_candidat}, merci pour votre candidature au poste de {poste}. '
            'Après réflexion, nous avons décidé de poursuivre avec un autre profil. '
            'Nous gardons votre profil pour de futures opportunités.',
        createdAt: now,
      ),
      MessageTemplate(
        templateId: '',
        title: 'Offre formelle',
        body: 'Bonjour {prénom_candidat}, nous sommes ravis de vous proposer le poste de '
            '{poste} chez {nom_entreprise} à {lieu}, à partir du {date}. '
            'Pouvez-vous me confirmer votre intérêt ?',
        createdAt: now,
      ),
      MessageTemplate(
        templateId: '',
        title: 'Demande d\'informations complémentaires',
        body: 'Bonjour {prénom_candidat}, pourriez-vous me communiquer quelques '
            'informations complémentaires sur votre expérience pour le poste de {poste} ?',
        createdAt: now,
      ),
    ];
  }
}
