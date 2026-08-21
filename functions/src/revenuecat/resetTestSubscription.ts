import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';
import { planFromProductId } from './planMapping';

/**
 * Résiliation en environnement de développement (Test Store RevenueCat).
 *
 * En production, la résiliation d'un abonnement auto-renouvelable passe
 * OBLIGATOIREMENT par le store (Apple/Google l'imposent) — jamais par ce
 * Callable. Ici on couvre uniquement le Test Store, qui n'a pas de page de
 * gestion : on réinitialise le client RevenueCat de test et on repasse le
 * document Firestore au plan Gratuit.
 *
 * Garde-fou : si le client possède un abonnement provenant d'un VRAI store
 * (app_store / play_store / amazon / stripe), on refuse — impossible d'effacer
 * par erreur un abonnement payant réel.
 */

interface RcSubscription {
  store?: string;
}
interface RcSubscriber {
  subscriptions?: Record<string, RcSubscription>;
}

const REAL_STORES = new Set(['app_store', 'play_store', 'amazon', 'stripe', 'mac_app_store']);

export const resetTestSubscription = onCall(
  { region: 'europe-west1', enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required.');
    }
    const userId = request.auth.uid;
    const secret = process.env.REVENUECAT_SECRET_KEY;
    if (!secret) {
      throw new HttpsError('failed-precondition', 'Réinitialisation indisponible.');
    }

    const headers = { Authorization: `Bearer ${secret}` };

    // 1. Vérifie qu'aucun abonnement d'un vrai store n'existe (anti-production).
    try {
      const resp = await fetch(
        `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(userId)}`,
        { headers }
      );
      if (resp.ok) {
        const json = (await resp.json()) as { subscriber?: RcSubscriber };
        const subs = json.subscriber?.subscriptions ?? {};
        for (const [productId, sub] of Object.entries(subs)) {
          if (planFromProductId(productId) && sub.store && REAL_STORES.has(sub.store)) {
            throw new HttpsError(
              'failed-precondition',
              'Résiliation via le store requise pour un abonnement réel.'
            );
          }
        }
      }
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      logger.warn('resetTestSubscription: vérification store échouée', e);
    }

    // 2. Efface le client de test côté RevenueCat.
    try {
      await fetch(
        `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(userId)}`,
        { method: 'DELETE', headers }
      );
    } catch (e) {
      logger.error('resetTestSubscription: suppression RevenueCat échouée', e);
      throw new HttpsError('unavailable', 'RevenueCat injoignable.');
    }

    // 3. Repasse Firestore au plan Gratuit et retire le badge vérifié.
    const db = admin.firestore();
    await db.collection('recruiter_subscriptions').doc(userId).set(
      {
        userId,
        plan: 'free',
        status: 'active',
        cancelAtPeriodEnd: false,
        endDate: null,
        syncedAt: new Date().toISOString(),
      },
      { merge: true }
    );

    try {
      const profiles = await db
        .collection('recruiter_profiles')
        .where('userId', '==', userId)
        .get();
      await Promise.all(
        profiles.docs.map((d) => d.ref.update({ isVerifiedEmployer: false }))
      );
    } catch (e) {
      logger.warn('resetTestSubscription: badge non mis à jour', e);
    }

    logger.info('resetTestSubscription: client de test réinitialisé', { userId });
    return { plan: 'free' };
  }
);
