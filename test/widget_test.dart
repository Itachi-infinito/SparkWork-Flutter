import 'package:flutter_test/flutter_test.dart';
import 'package:sparkwork/core/constants/app_skills.dart';
import 'package:sparkwork/models/candidate_profile.dart';
import 'package:sparkwork/models/job_offer.dart';
import 'package:sparkwork/services/compatibility_service.dart';

CandidateProfile _candidate({
  String contractType = '',
  String level = '',
  List<String> skills = const [],
  int salaryMin = 0,
  int salaryMax = 0,
}) =>
    CandidateProfile(
      profileId: 'p1',
      userId: 'u1',
      fullName: 'Test Candidat',
      desiredContractType: contractType,
      desiredLevel: level,
      skills: skills,
      desiredSalaryMin: salaryMin,
      desiredSalaryMax: salaryMax,
    );

JobOffer _offer({
  String contractType = '',
  String level = '',
  String requiredSkills = '',
  String niceSkills = '',
  int salaryMin = 0,
  int salaryMax = 0,
}) =>
    JobOffer(
      jobOfferId: 'o1',
      recruiterUserId: 'r1',
      title: 'Serveur',
      companyName: 'Le Gourmet',
      location: 'Bruxelles',
      contractType: contractType,
      description: 'desc',
      salaryMin: salaryMin,
      salaryMax: salaryMax,
      requiredSkills: requiredSkills,
      niceToHaveSkills: niceSkills,
      remoteMode: '',
      level: level,
    );

void main() {
  final service = CompatibilityService();

  group('CompatibilityService', () {
    test('score maximal quand tout correspond', () {
      final score = service.calculateScore(
        _candidate(
          contractType: 'CDI',
          level: 'Confirmé',
          skills: ['Service en salle', 'Encaissement'],
          salaryMin: 1900,
          salaryMax: 2100,
        ),
        _offer(
          contractType: 'CDI',
          level: 'Confirmé',
          requiredSkills: 'Service en salle, Encaissement',
          salaryMin: 1900,
          salaryMax: 2100,
        ),
      );
      expect(score, 100);
    });

    test('contrat multi-valeurs "CDI,CDD" matche une offre CDI', () {
      final withMatch = service.calculateScore(
        _candidate(contractType: 'CDI,CDD'),
        _offer(contractType: 'CDI'),
      );
      final withoutMatch = service.calculateScore(
        _candidate(contractType: 'Intérim'),
        _offer(contractType: 'CDI'),
      );
      expect(withMatch - withoutMatch, 15);
    });

    test('compétences partielles = points proportionnels', () {
      final score = service.calculateScore(
        _candidate(skills: ['Plonge']),
        _offer(requiredSkills: 'Plonge, Cuisine chaude'),
      );
      // 1/2 des 50 pts skills + 15 nice + 8 contrat + 5 niveau + 5 salaire
      expect(score, 25 + 15 + 8 + 5 + 5);
    });

    test('le score reste borné entre 0 et 100', () {
      final score = service.calculateScore(_candidate(), _offer());
      expect(score, inInclusiveRange(0, 100));
    });
  });

  group('AppSkills', () {
    test('parseSkills gère espaces et valeurs vides', () {
      expect(AppSkills.parseSkills('CDI, CDD , ,Stage'),
          ['CDI', 'CDD', 'Stage']);
      expect(AppSkills.parseSkills(''), isEmpty);
    });

    test('normalizeLevel migre les anciennes valeurs', () {
      expect(AppSkills.normalizeLevel('Intermédiaire'), 'Confirmé');
      expect(AppSkills.normalizeLevel('Senior'), 'Senior');
    });

    test('normalizeRemote migre les anciennes valeurs', () {
      expect(AppSkills.normalizeRemote('Hybride'), 'Télétravail partiel');
      expect(AppSkills.normalizeRemote('Télétravail'), 'Télétravail total');
      expect(AppSkills.normalizeRemote('Présentiel'), 'Présentiel');
    });
  });

  group('CandidateProfile.fromMap', () {
    test('normalise niveau et télétravail à la lecture', () {
      final p = CandidateProfile.fromMap({
        'userId': 'u1',
        'fullName': 'Test',
        'desiredLevel': 'Intermédiaire',
        'remotePreference': 'Hybride',
        'skills': 'Plonge, Service en salle',
      });
      expect(p.desiredLevel, 'Confirmé');
      expect(p.remotePreference, 'Télétravail partiel');
      expect(p.skills, ['Plonge', 'Service en salle']);
    });
  });
}
