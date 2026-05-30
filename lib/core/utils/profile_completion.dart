import 'package:flutter/material.dart';
import '../../models/candidate_profile.dart';

class ProfileCompletion {
  static int calculate(CandidateProfile? profile) {
    if (profile == null) return 0;
    int score = 0;
    if (profile.fullName.isNotEmpty) score += 10;
    if (profile.location.isNotEmpty) score += 15;
    if (profile.desiredContractType.isNotEmpty) score += 10;
    if (profile.desiredLevel.isNotEmpty) score += 10;
    if (profile.skillList.isNotEmpty) score += 20;
    if (profile.bio.length >= 20) score += 20;
    if (profile.desiredSalaryMin > 0) score += 10;
    if (profile.remotePreference.isNotEmpty) score += 5;
    return score;
  }

  static List<CompletionItem> missing(CandidateProfile? profile) {
    if (profile == null) return [];
    return [
      if (profile.location.isEmpty)
        const CompletionItem('Localisation', Icons.location_on_outlined),
      if (profile.desiredContractType.isEmpty)
        const CompletionItem('Type de contrat', Icons.work_outline),
      if (profile.desiredLevel.isEmpty)
        const CompletionItem('Niveau d\'expérience', Icons.trending_up),
      if (profile.skillList.isEmpty)
        const CompletionItem('Compétences', Icons.star_outline),
      if (profile.bio.length < 20)
        const CompletionItem('Biographie', Icons.edit_outlined),
      if (profile.desiredSalaryMin == 0)
        const CompletionItem('Salaire souhaité', Icons.euro),
      if (profile.remotePreference.isEmpty)
        const CompletionItem('Télétravail', Icons.home_work_outlined),
    ];
  }

  static String label(int score) {
    if (score >= 90) return 'Profil complet 🎉';
    if (score >= 70) return 'Profil presque complet';
    if (score >= 40) return 'Profil en cours';
    return 'Profil incomplet';
  }

  static Color color(int score) {
    if (score >= 80) return const Color(0xFF10B981);
    if (score >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}

class CompletionItem {
  final String label;
  final IconData icon;
  const CompletionItem(this.label, this.icon);
}