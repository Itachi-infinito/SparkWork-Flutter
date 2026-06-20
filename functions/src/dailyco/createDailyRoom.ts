import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';

// eslint-disable-next-line @typescript-eslint/no-require-imports
const fetch = require('node-fetch') as typeof import('node-fetch').default;

const DAILY_API_BASE = 'https://api.daily.co/v1';

/**
 * Entretien vidéo intégré (Pro) via Daily.co. Crée une salle réutilisable
 * dont l'URL est ensuite collée dans le champ "lien de réunion" existant
 * de la proposition d'entretien (cf. Interview.meetingLink /
 * showProposeInterviewDialog) — pas de nouvelle collection, on réutilise
 * le flow de planification déjà en place.
 *
 * ⚠️ Nécessite un compte Daily.co et la variable d'environnement
 * DAILY_API_KEY (Firebase Functions config/secrets) — non fonctionnel
 * tant que ce compte n'est pas créé, comme Veriff/Stripe/RevenueCat.
 */
export const createDailyRoom = onCall(
  { region: 'europe-west1' },
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
    if (matchDoc.data()!.recruiterUserId !== request.auth.uid) {
      throw new HttpsError('permission-denied', 'Seul le recruteur peut créer cette salle.');
    }

    const apiKey = process.env.DAILY_API_KEY ?? '';
    if (!apiKey) {
      logger.error('DAILY_API_KEY not set');
      throw new HttpsError('internal', 'Service d\'entretien vidéo non configuré.');
    }

    const expiryUnix = Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 30; // 30 jours

    const response = await fetch(`${DAILY_API_BASE}/rooms`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        privacy: 'private',
        properties: {
          exp: expiryUnix,
          enable_chat: true,
          enable_screenshare: true,
        },
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      logger.error('Daily.co room creation failed', { errorText });
      throw new HttpsError('internal', 'Échec de la création de la salle d\'entretien.');
    }

    const result = await response.json() as { url: string };
    return { roomUrl: result.url };
  }
);
