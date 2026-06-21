import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';
import { sendPushToUser } from '../utils/sendPush';

const RADIUS_KM = 30;
const MIN_SKILL_SCORE = 70;

function haversineKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) * Math.cos((lat2 * Math.PI) / 180) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/**
 * SparkBoost Pro intelligent — cible uniquement les candidats "Disponible
 * maintenant" (signal d'activité récente — aucun champ lastActiveAt distinct
 * n'existe encore dans candidate_profiles, TODO à affiner), avec un bon
 * matching compétences et dans le rayon géographique de l'offre.
 * Le boost simple (Starter) reste géré côté client par
 * SubscriptionService.useBoost — celui-ci est réservé au plan Pro.
 */
export const activateSmartBoost = onCall(
  { region: 'europe-west1', enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required.');
    }
    const recruiterId = request.auth.uid;
    const { offerId } = request.data as { offerId?: string };
    if (!offerId) throw new HttpsError('invalid-argument', 'offerId requis.');

    const db = admin.firestore();
    const offerDoc = await db.collection('job_offers').doc(offerId).get();
    if (!offerDoc.exists) throw new HttpsError('not-found', 'Offre introuvable.');
    const offer = offerDoc.data()!;
    if (offer.recruiterUserId !== recruiterId) {
      throw new HttpsError('permission-denied', 'Cette offre ne vous appartient pas.');
    }

    const requiredSkills = String(offer.requiredSkills ?? '')
      .split(',').map((s) => s.trim().toLowerCase()).filter(Boolean);

    const candidatesSnap = await db
      .collection('candidate_profiles')
      .where('isAvailableNow', '==', true)
      .get();

    const targets: string[] = [];
    const now = Date.now();

    for (const doc of candidatesSnap.docs) {
      const c = doc.data();
      if (c.availableNowUntil && new Date(c.availableNowUntil).getTime() < now) continue;

      if (offer.latitude && offer.longitude && c.latitude && c.longitude) {
        const distance = haversineKm(offer.latitude, offer.longitude, c.latitude, c.longitude);
        if (distance > RADIUS_KM) continue;
      }

      const candidateSkills = new Set(
        String(c.skills ?? '').split(',').map((s: string) => s.trim().toLowerCase()).filter(Boolean)
      );
      const skillScore = requiredSkills.length === 0
        ? 100
        : Math.round((requiredSkills.filter((s) => candidateSkills.has(s)).length / requiredSkills.length) * 100);
      if (skillScore < MIN_SKILL_SCORE) continue;

      targets.push(c.userId as string);
    }

    await Promise.all(targets.map((candidateId) =>
      sendPushToUser(
        candidateId,
        {
          title: 'Une offre qui vous correspond',
          body: `${offer.title} chez ${offer.companyName} pourrait vous intéresser !`,
        },
        { type: 'boosted_offer', offerId }
      )
    ));

    await db.collection('job_offers').doc(offerId).update({
      isBoosted: true,
      boostedAt: new Date().toISOString(),
      lastSmartBoostTargetCount: targets.length,
    });

    logger.info('SmartBoost activated', { offerId, recruiterId, targetCount: targets.length });

    return { targetCount: targets.length, radiusKm: RADIUS_KM };
  }
);
