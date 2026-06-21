import * as admin from 'firebase-admin';
import { computeSparkScoreFactors } from '../sparkscore/scoreEngine';

/**
 * Construit la fiche de candidature pour un match donné, en supposant que
 * l'éligibilité Pro a déjà été vérifiée par l'appelant. Partagé entre le
 * déclencheur automatique (à la création du match) et la régénération à
 * la demande (si le recruteur est passé Pro après coup, ou si le
 * déclencheur a échoué silencieusement la première fois).
 */
export async function buildMatchReport(
  db: admin.firestore.Firestore,
  matchId: string,
  match: Record<string, any> // eslint-disable-line @typescript-eslint/no-explicit-any
): Promise<boolean> {
  const [offerDoc, candidateSnap, ratingDoc, verificationDoc, recommendationsSnap] = await Promise.all([
    db.collection('job_offers').doc(match.jobOfferId).get(),
    db.collection('candidate_profiles').where('userId', '==', match.candidateUserId).limit(1).get(),
    db.collection('average_ratings').doc(match.candidateUserId).get(),
    db.collection('verifications').doc(match.candidateUserId).get(),
    db.collection('recommendations')
      .where('candidateId', '==', match.candidateUserId)
      .where('isPublished', '==', true)
      .get(),
  ]);

  if (!offerDoc.exists || candidateSnap.empty) return false;
  const offer = offerDoc.data()!;
  const candidate = candidateSnap.docs[0].data();
  const rating = ratingDoc.data();

  const { globalScore, factors } = computeSparkScoreFactors(offer, candidate, rating);

  const requiredSkills = String(offer.requiredSkills ?? '')
    .split(',').map((s) => s.trim().toLowerCase()).filter(Boolean);
  const candidateSkillList = String(candidate.skills ?? '')
    .split(',').map((s) => s.trim()).filter(Boolean);
  const matchingSkills = candidateSkillList.filter((s) => requiredSkills.includes(s.toLowerCase()));
  const otherSkills = candidateSkillList.filter((s) => !requiredSkills.includes(s.toLowerCase()));

  const isAvailableNow = candidate.isAvailableNow === true &&
    candidate.availableNowUntil &&
    new Date(candidate.availableNowUntil).getTime() > Date.now();

  const report = {
    matchId,
    candidateId: match.candidateUserId,
    recruiterId: match.recruiterUserId,
    offerId: match.jobOfferId,
    candidateName: candidate.fullName ?? '',
    candidatePhotoUrl: candidate.photoUrl ?? null,
    jobTitle: candidate.jobTitle ?? '',
    sparkScore: globalScore,
    sparkScoreFactors: factors,
    matchingSkills,
    otherSkills,
    averageRating: rating?.averageScore ?? null,
    totalReviews: rating?.totalReviews ?? 0,
    verificationStatus: verificationDoc.data()?.status ?? 'unverified',
    recommendationCount: recommendationsSnap.size,
    isAvailableNow,
    generatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await db.collection('match_reports').doc(matchId).set(report);
  return true;
}

export async function isRecruiterPro(
  db: admin.firestore.Firestore,
  recruiterUserId: string
): Promise<boolean> {
  const sub = (await db.collection('recruiter_subscriptions').doc(recruiterUserId).get()).data();
  const plan = sub?.plan as string | undefined;
  const status = sub?.status as string | undefined;
  const trialEnd = sub?.trialEndDate as string | undefined;
  const isTrialActive = status === 'trial' && !!trialEnd && new Date(trialEnd).getTime() > Date.now();
  return (status === 'active' && plan === 'pro') || isTrialActive;
}
