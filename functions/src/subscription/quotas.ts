import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';

/**
 * Quotas de swipes et crédits de boost — écriture serveur UNIQUEMENT.
 *
 * Historiquement, le client écrivait lui-même `swipe_quotas` et
 * `boost_credits` : n'importe quel recruteur pouvait remettre son compteur
 * à zéro ou se créditer des boosts (fonctionnalité payante). Les Security
 * Rules refusent désormais toute écriture client sur ces collections ; ces
 * deux Callables transactionnels sont l'unique chemin d'écriture.
 *
 * Les dates restent des chaînes ISO8601 pour compatibilité avec les
 * documents existants créés par l'ancien code client.
 */

const PLAN_LIMITS: Record<string, { dailySwipes: number; monthlyBoosts: number }> = {
  free: { dailySwipes: 5, monthlyBoosts: 0 },
  starter: { dailySwipes: 50, monthlyBoosts: 1 },
  pro: { dailySwipes: -1, monthlyBoosts: 3 }, // -1 = illimité
};

/**
 * Résout le plan effectif côté serveur — même logique que
 * SubscriptionService.getSubscription côté client : mode restreint => free,
 * essai actif => pro, statut active => plan souscrit, sinon free.
 */
async function resolveEffectivePlan(
  db: admin.firestore.Firestore,
  userId: string
): Promise<'free' | 'starter' | 'pro'> {
  const userDoc = await db.collection('users').doc(userId).get();
  if (userDoc.data()?.isRestricted === true) return 'free';

  const subDoc = await db.collection('recruiter_subscriptions').doc(userId).get();
  if (!subDoc.exists) return 'free';
  const sub = subDoc.data() ?? {};

  if (sub.status === 'trial' && typeof sub.trialEndDate === 'string') {
    if (new Date(sub.trialEndDate).getTime() > Date.now()) return 'pro';
    return 'free';
  }
  if (sub.status === 'active') {
    const plan = String(sub.plan ?? 'free');
    return plan === 'starter' || plan === 'pro' ? plan : 'free';
  }
  return 'free';
}

/**
 * Consomme un swipe du quota journalier (fenêtre glissante de 24h à partir
 * du premier swipe). Retourne { allowed, remaining } — remaining = -1 pour
 * un plan illimité.
 */
export const consumeSwipe = onCall(
  { region: 'europe-west1', enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required.');
    }
    const userId = request.auth.uid;
    const db = admin.firestore();

    const plan = await resolveEffectivePlan(db, userId);
    const max = PLAN_LIMITS[plan].dailySwipes;
    if (max === -1) return { allowed: true, remaining: -1 };

    const quotaRef = db.collection('swipe_quotas').doc(userId);
    try {
      return await db.runTransaction(async (tx) => {
        const doc = await tx.get(quotaRef);
        const now = new Date();
        let used = 0;
        let resetAt = now;

        if (doc.exists) {
          const data = doc.data()!;
          const parsed = new Date(String(data.resetAt ?? ''));
          if (!isNaN(parsed.getTime()) && now.getTime() - parsed.getTime() < 24 * 3600 * 1000) {
            resetAt = parsed;
            used = Number(data.used ?? 0);
          }
        }

        if (used >= max) {
          return { allowed: false, remaining: 0 };
        }

        tx.set(quotaRef, {
          userId,
          used: used + 1,
          resetAt: resetAt.toISOString(),
          max,
        });
        return { allowed: true, remaining: max - used - 1 };
      });
    } catch (e) {
      logger.error('consumeSwipe transaction failed', { userId, error: e });
      // Ne jamais bloquer l'utilisateur sur une erreur interne.
      return { allowed: true, remaining: -1 };
    }
  }
);

/**
 * Consomme un crédit de boost mensuel et marque l'offre comme boostée.
 * Vérifie que l'offre appartient bien à l'appelant.
 */
export const useBoost = onCall(
  { region: 'europe-west1', enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required.');
    }
    const userId = request.auth.uid;
    const offerId = String(request.data?.offerId ?? '');
    if (!offerId) {
      throw new HttpsError('invalid-argument', 'offerId requis.');
    }

    const db = admin.firestore();
    const plan = await resolveEffectivePlan(db, userId);
    const monthly = PLAN_LIMITS[plan].monthlyBoosts;
    if (monthly === 0) return { allowed: false, remaining: 0 };

    const boostRef = db.collection('boost_credits').doc(userId);
    const offerRef = db.collection('job_offers').doc(offerId);

    return await db.runTransaction(async (tx) => {
      const [boostDoc, offerDoc] = await Promise.all([tx.get(boostRef), tx.get(offerRef)]);

      if (!offerDoc.exists || offerDoc.data()?.recruiterUserId !== userId) {
        throw new HttpsError('permission-denied', 'Offre introuvable ou non possédée.');
      }

      // Fenêtre calendaire mensuelle (même convention que l'ancien client).
      const now = new Date();
      let available = monthly;
      if (boostDoc.exists) {
        const data = boostDoc.data()!;
        const resetAt = new Date(String(data.resetAt ?? ''));
        if (
          !isNaN(resetAt.getTime()) &&
          resetAt.getMonth() === now.getMonth() &&
          resetAt.getFullYear() === now.getFullYear()
        ) {
          available = Math.min(Number(data.available ?? monthly), monthly);
        }
      }

      if (available <= 0) return { allowed: false, remaining: 0 };

      tx.set(boostRef, {
        userId,
        available: available - 1,
        resetAt: now.toISOString(),
        lastBoostedOfferId: offerId,
      });
      tx.update(offerRef, {
        isBoosted: true,
        boostedAt: now.toISOString(),
      });
      return { allowed: true, remaining: available - 1 };
    });
  }
);
