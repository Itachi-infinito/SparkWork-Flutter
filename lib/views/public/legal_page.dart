import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Pages légales statiques : CGU et politique de confidentialité.
/// ⚠️ Contenu de base à faire valider par un juriste avant publication.
class LegalPage extends StatelessWidget {
  final bool isPrivacy;
  const LegalPage({super.key, required this.isPrivacy});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isPrivacy
            ? 'Politique de confidentialité'
            : 'Conditions d\'utilisation'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: (isPrivacy ? _privacySections : _termsSections)
              .map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.$1,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 8),
                        Text(s.$2,
                            style: const TextStyle(
                                fontSize: 13,
                                height: 1.6,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

const _termsSections = <(String, String)>[
  (
    '1. Objet',
    'SparkWork est une plateforme de mise en relation entre candidats et '
        'recruteurs du secteur Horeca (hôtellerie, restauration, café). '
        'En créant un compte, vous acceptez les présentes conditions '
        'générales d\'utilisation.'
  ),
  (
    '2. Compte utilisateur',
    'Vous vous engagez à fournir des informations exactes et à jour. '
        'Vous êtes responsable de la confidentialité de vos identifiants. '
        'Un seul compte par personne est autorisé. Les comptes créés à des '
        'fins frauduleuses, de spam ou d\'usurpation d\'identité seront '
        'supprimés.'
  ),
  (
    '3. Contenu publié',
    'Vous êtes seul responsable du contenu que vous publiez (profil, '
        'offres, messages). Sont interdits : les contenus discriminatoires, '
        'haineux, à caractère sexuel, les fausses offres d\'emploi et toute '
        'forme de harcèlement. SparkWork se réserve le droit de retirer '
        'tout contenu signalé et de suspendre les comptes concernés.'
  ),
  (
    '4. Signalement et blocage',
    'Tout utilisateur peut signaler un profil, une offre ou un message '
        'inapproprié, et bloquer un autre utilisateur. Les signalements '
        'sont examinés dans les meilleurs délais.'
  ),
  (
    '5. Relation de travail',
    'SparkWork facilite la mise en relation mais n\'est pas partie aux '
        'contrats de travail conclus entre candidats et recruteurs. La '
        'vérification des informations (diplômes, références, permis de '
        'travail) relève de la responsabilité des parties.'
  ),
  (
    '6. Suppression de compte',
    'Vous pouvez supprimer votre compte à tout moment depuis les '
        'Paramètres. La suppression entraîne l\'effacement de votre profil, '
        'de vos likes, matches et messages.'
  ),
  (
    '7. Modification des CGU',
    'SparkWork peut modifier les présentes conditions. Vous serez informé '
        'des changements significatifs dans l\'application.'
  ),
];

const _privacySections = <(String, String)>[
  (
    '1. Données collectées',
    'Nous collectons les données que vous fournissez : nom, email, ville, '
        'compétences, préférences professionnelles, biographie, photo de '
        'profil, ainsi que vos interactions sur la plateforme (likes, '
        'matches, messages).'
  ),
  (
    '2. Utilisation des données',
    'Vos données servent exclusivement au fonctionnement du service : '
        'calcul de compatibilité entre profils et offres, mise en relation, '
        'messagerie. Elles ne sont ni vendues ni transmises à des tiers à '
        'des fins commerciales.'
  ),
  (
    '3. Hébergement',
    'Les données sont hébergées sur Google Firebase (Google Cloud). Les '
        'transferts sont chiffrés (TLS) et l\'accès est protégé par des '
        'règles de sécurité strictes.'
  ),
  (
    '4. Visibilité de votre profil',
    'Votre profil candidat (hors email) est visible des recruteurs '
        'inscrits. Les offres des recruteurs sont visibles des candidats '
        'inscrits. Vos messages ne sont visibles que de votre '
        'interlocuteur.'
  ),
  (
    '5. Vos droits (RGPD)',
    'Conformément au RGPD, vous disposez d\'un droit d\'accès, de '
        'rectification et de suppression de vos données. La rectification '
        'se fait via l\'édition de votre profil ; la suppression complète '
        'via Paramètres > Supprimer mon compte. Pour toute autre demande : '
        'contact@sparkwork.app.'
  ),
  (
    '6. Conservation',
    'Vos données sont conservées tant que votre compte est actif. La '
        'suppression du compte efface définitivement vos données '
        'personnelles de nos systèmes.'
  ),
  (
    '7. Cookies et traceurs',
    'L\'application n\'utilise pas de cookies publicitaires. Seules des '
        'données techniques anonymes peuvent être collectées à des fins de '
        'stabilité du service.'
  ),
];
