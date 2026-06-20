import * as admin from 'firebase-admin';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions/v2';
import { computeSparkScoreFactors } from '../sparkscore/scoreEngine';

/**
 * Génère automatiquement une fiche de candidature synthétique quand un
 * match se crée avec une offre d'un recruteur Pro. Mise en cache dans
 * match_reports/{matchId} — lue par l'app depuis la conversation et la
 * liste des matchs (jamais recalculée côté client).
 */
export const generateMatchReport = onDocumentCreated(
  { document: 'matches/{matchId}', region: 'europe-west1' },
  async (event) => {
    const match = event.data?.data();
    const matchId = event.params.matchId;
    if (!match) return;

    const db = admin.firestore();

    try {
      const recruiterSubDoc = await db.collection('recruiter_subscriptions').doc(match.recruiterUserId).get();
      const plan = recruiterSubDoc.data()?.plan as string | undefined;
      const status = recruiterSubDoc.data()?.status as string | undefined;
      const trialEnd = recruiterSubDoc.data()?.trialEndDate as string | undefined;
      const isTrialActive = status === 'trial' && trialEnd && new Date(trialEnd).getTime() > Date.now();
      const isPro = (status === 'active' && plan === 'pro') || isTrialActive;
      if (!isPro) return; // rapport réservé au plan Pro

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

      if (!offerDoc.exists || candidateSnap.empty) return;
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
        // TODO: export PDF — non implémenté, écran natif uniquement pour l'instant.
      };

      await db.collection('match_reports').doc(matchId).set(report);
      logger.info(`Match report generated for ${matchId}`);
    } catch (e) {
      logger.error(`generateMatchReport failed for ${matchId}`, e);
    }
  }
);
