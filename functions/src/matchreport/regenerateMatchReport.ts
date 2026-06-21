import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { buildMatchReport, isRecruiterPro } from './buildMatchReport';

/**
 * Régénère à la demande le rapport de candidature d'un match existant —
 * couvre le cas où le recruteur est passé Pro APRÈS la création du match
 * (le déclencheur automatique generateMatchReport ne vérifie l'éligibilité
 * qu'une fois, au moment précis de la création).
 */
export const regenerateMatchReport = onCall(
  { region: 'europe-west1', enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required.');
    }
    const { matchId } = request.data as { matchId?: string };
    if (!matchId) {
      throw new HttpsError('invalid-argument', 'matchId requis.');
    }

    const db = admin.firestore();
    const matchDoc = await db.collection('matches').doc(matchId).get();
    if (!matchDoc.exists) {
      throw new HttpsError('not-found', 'Match introuvable.');
    }
    const match = matchDoc.data()!;
    if (match.recruiterUserId !== request.auth.uid) {
      throw new HttpsError('permission-denied', 'Accès refusé à ce match.');
    }

    if (!(await isRecruiterPro(db, match.recruiterUserId))) {
      throw new HttpsError('permission-denied', 'Le rapport de candidature est réservé au plan Pro.');
    }

    const ok = await buildMatchReport(db, matchId, match);
    if (!ok) {
      throw new HttpsError('not-found', 'Offre ou profil candidat introuvable.');
    }
    return { generated: true };
  }
);
