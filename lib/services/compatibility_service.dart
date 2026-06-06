import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/candidate_profile.dart';
import '../models/job_offer.dart';
import '../core/constants/app_skills.dart';

final compatibilityServiceProvider = Provider<CompatibilityService>((ref) {
  return CompatibilityService();
});

class CompatibilityService {
  int calculateScore(CandidateProfile candidate, JobOffer offer) {
    int score = 0;

    // Skills: 50 pts
    if (offer.requiredSkillList.isNotEmpty) {
      final candidateSkills = candidate.skillList.map((s) => s.toLowerCase()).toSet();
      int matched = 0;
      for (final skill in offer.requiredSkillList) {
        if (candidateSkills.contains(skill.toLowerCase())) matched++;
      }
      score += ((matched / offer.requiredSkillList.length) * 50).round();
    } else {
      score += 50;
    }

    // Nice-to-have skills: 15 pts
    if (offer.niceSkillList.isNotEmpty) {
      final candidateSkills = candidate.skillList.map((s) => s.toLowerCase()).toSet();
      int matched = 0;
      for (final skill in offer.niceSkillList) {
        if (candidateSkills.contains(skill.toLowerCase())) matched++;
      }
      score += ((matched / offer.niceSkillList.length) * 15).round();
    } else {
      score += 15;
    }

    // Contract type: 15 pts
    if (candidate.desiredContractType.isNotEmpty && offer.contractType.isNotEmpty) {
      final candidateTypes = AppSkills.parseSkills(candidate.desiredContractType)
          .map((t) => t.toLowerCase())
          .toList();
      if (candidateTypes.contains(offer.contractType.toLowerCase())) {
        score += 15;
      }
    } else {
      score += 8;
    }

    // Level: 10 pts
    if (candidate.desiredLevel.isNotEmpty && offer.level.isNotEmpty) {
      if (candidate.desiredLevel.toLowerCase() == offer.level.toLowerCase()) {
        score += 10;
      }
    } else {
      score += 5;
    }

    // Salary: 10 pts
    if (candidate.hasSalary && offer.hasSalary) {
      final candidateMid = (candidate.desiredSalaryMin + candidate.desiredSalaryMax) / 2;
      final offerMid = (offer.salaryMin + offer.salaryMax) / 2;
      final diff = (candidateMid - offerMid).abs();
      if (diff <= 200) score += 10;
      else if (diff <= 500) score += 6;
      else if (diff <= 1000) score += 3;
    } else {
      score += 5;
    }

    return score.clamp(0, 100);
  }
}