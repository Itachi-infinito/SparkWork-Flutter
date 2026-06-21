import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';

// eslint-disable-next-line @typescript-eslint/no-require-imports
const fetch = require('node-fetch') as typeof import('node-fetch').default;

const STRIPE_API_BASE = 'https://api.stripe.com/v1';
const MAX_ATTEMPTS = 3;

/**
 * Alternative à Veriff utilisant Stripe Identity. Suit exactement le même
 * patron que createVeriffSession.ts (appel REST direct via node-fetch,
 * pas de SDK Stripe, clé via variable d'environnement) pour rester
 * cohérent avec l'intégration existante.
 *
 * ⚠️ Nécessite un compte Stripe avec Identity activé et la variable
 * d'environnement STRIPE_SECRET_KEY (Firebase Functions config/secrets),
 * exactement comme VERIFF_API_KEY pour Veriff ou les clés RevenueCat —
 * non fonctionnel tant que ce compte n'est pas créé et configuré.
 */
export const createStripeIdentitySession = onCall(
  { region: 'europe-west1', enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required.');
    }
    const userId = request.auth.uid;

    const db = admin.firestore();
    const verifDoc = await db.collection('verifications').doc(userId).get();
    const existing = verifDoc.exists ? verifDoc.data()! : {};
    const attemptCount: number = existing.attemptCount ?? 0;

    if (attemptCount >= MAX_ATTEMPTS) {
      throw new HttpsError(
        'resource-exhausted',
        'Nombre maximum de tentatives de vérification atteint.'
      );
    }

    const apiKey = process.env.STRIPE_SECRET_KEY ?? '';
    if (!apiKey) {
      logger.error('STRIPE_SECRET_KEY not set');
      throw new HttpsError('internal', 'Service de vérification non configuré.');
    }

    const body = new URLSearchParams({
      type: 'document',
      'metadata[userId]': userId,
      'options[document][require_matching_selfie]': 'true',
    });

    const response = await fetch(`${STRIPE_API_BASE}/identity/verification_sessions`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body,
    });

    if (!response.ok) {
      const errorText = await response.text();
      logger.error('Stripe Identity session creation failed', { errorText });
      throw new HttpsError('internal', 'Échec de la création de la session de vérification.');
    }

    const result = await response.json() as { id: string; url: string };

    await db.collection('verifications').doc(userId).set(
      {
        userId,
        sessionId: result.id,
        provider: 'stripe',
        status: 'pending',
        submittedAt: admin.firestore.FieldValue.serverTimestamp(),
        attemptCount: attemptCount + 1,
        declineReason: null,
        decidedAt: null,
      },
      { merge: true }
    );

    const profileSnap = await db
      .collection('candidate_profiles')
      .where('userId', '==', userId)
      .limit(1)
      .get();
    if (!profileSnap.empty) {
      await profileSnap.docs[0].ref.update({ verificationStatus: 'pending' });
    }

    return { sessionUrl: result.url, sessionId: result.id };
  }
);
