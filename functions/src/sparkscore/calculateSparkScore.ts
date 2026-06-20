import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { computeSparkScoreFactors } from './scoreEngine';

const CACHE_TTL_MS = 24 * 60 * 60 * 1000;

/**
 * SparkScore IA détaillé — calculé côté serveur, mis en cache 24h dans
 * sparkscores/{offerId}_{candidateId}. Le détail par facteur n'est exposé
 * au client que pour les recruteurs Pro (filtré côté Flutter), mais le
 * calcul lui-même est toujours fait ici pour rester la source de vérité.
 * La logique de pondération vit dans scoreEngine.ts, partagée avec la
 * génération de rapport de candidature.
 */
export const calculateSparkScore = onCall(
  { region: 'europe-west1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required.');
    }
    const { offerId, candidateId } = request.data as { offerId?: string; candidateId?: string };
    if (!offerId || !candidateId) {
      throw new HttpsError('invalid-argument', 'offerId et candidateId requis.');
    }

    const db = admin.firestore();
    const cacheId = `${offerId}_${candidateId}`;
    const cacheRef = db.collection('sparkscores').doc(cacheId);
    const cached = await cacheRef.get();
    if (cached.exists) {
      const data = cached.data()!;
      if (Date.now() - (data.computedAtMs as number) < CACHE_TTL_MS) {
        return data;
      }
    }

    const [offerDoc, candidateSnap, ratingDoc] = await Promise.all([
      db.collection('job_offers').doc(offerId).get(),
      db.collection('candidate_profiles').where('userId', '==', candidateId).limit(1).get(),
      db.collection('average_ratings').doc(candidateId).get(),
    ]);

    if (!offerDoc.exists || candidateSnap.empty) {
      throw new HttpsError('not-found', 'Offre ou candidat introuvable.');
    }

    const { globalScore, factors } = computeSparkScoreFactors(
      offerDoc.data()!,
      candidateSnap.docs[0].data(),
      ratingDoc.data()
    );

    const result = { offerId, candidateId, globalScore, factors, computedAtMs: Date.now() };
    await cacheRef.set(result);
    return result;
  }
);
