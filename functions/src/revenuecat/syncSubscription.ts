import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';
import { planFromProductId } from './planMapping';

/**
 * Réconciliation synchrone de l'abonnement depuis RevenueCat.
 *
 * Le webhook RevenueCat reste la voie principale pour les événements
 * asynchrones (renouvellements, incidents de paiement…), mais il peut avoir
 * du retard ou, en environnement Test Store, ne pas être configuré. Ce
 * Callable interroge directement l'API REST RevenueCat (source de vérité,
 * jamais le client qui pourrait mentir) et écrit `recruiter_subscriptions`
 * via l'Admin SDK — ce qui contourne légitimement les Security Rules.
 *
 * Appelé côté client après un achat, un restore, une annulation, et à
 * l'ouverture des écrans d'abonnement pour garantir un état toujours à jour.
 */

interface RcEntitlement {
  expires_date: string | null;
  purchase_date?: string;
  product_identifier?: string;
}

interface RcSubscription {
  expires_date: string | null;
  purchase_date?: string;
  unsubscribe_detected_at?: string | null;
  period_type?: string;
  store?: string;
}

interface RcSubscriber {
  entitlements?: Record<string, RcEntitlement>;
  subscriptions?: Record<string, RcSubscription>;
}

function isActive(expiresDate: string | null): boolean {
  if (expiresDate === null) return true; // lifetime
  return new Date(expiresDate).getTime() > Date.now();
}

export const syncSubscriptionStatus = onCall(
  { region: 'europe-west1', enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required.');
    }
    const userId = request.auth.uid;
    const secret = process.env.REVENUECAT_SECRET_KEY;
    if (!secret) {
      logger.error('syncSubscriptionStatus: REVENUECAT_SECRET_KEY manquante.');
      throw new HttpsError('failed-precondition', 'Sync indisponible.');
    }

    const db = admin.firestore();
    const subRef = db.collection('recruiter_subscriptions').doc(userId);

    // 1. Interroge RevenueCat pour l'état réel de cet utilisateur.
    let subscriber: RcSubscriber;
    try {
      const resp = await fetch(
        `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(userId)}`,
        { headers: { Authorization: `Bearer ${secret}` } }
      );
      if (!resp.ok) {
        throw new Error(`RevenueCat API ${resp.status}`);
      }
      const json = (await resp.json()) as { subscriber?: RcSubscriber };
      subscriber = json.subscriber ?? {};
    } catch (e) {
      logger.error('syncSubscriptionStatus: appel RevenueCat échoué', e);
      throw new HttpsError('unavailable', 'RevenueCat injoignable.');
    }

    // 2. Résout le plan de l'entitlement actif le plus RÉCEMMENT acheté.
    // Reflète le dernier choix de l'utilisateur (ex: passage Pro -> Starter,
    // où les deux peuvent rester actifs en Test Store). En production, un seul
    // entitlement est actif à la fois dans un même groupe d'abonnement — ce
    // « plus récent » correspond donc simplement au plan courant.
    let resolvedPlan = 'free';
    let latestPurchase = '';
    let latestExpiry: string | null = null;
    const entitlements = subscriber.entitlements ?? {};
    for (const ent of Object.values(entitlements)) {
      if (!isActive(ent.expires_date)) continue;
      const plan = planFromProductId(ent.product_identifier);
      if (!plan) continue;
      const purchase = ent.purchase_date ?? '';
      if (purchase >= latestPurchase) {
        latestPurchase = purchase;
        resolvedPlan = plan;
        latestExpiry = ent.expires_date;
      }
    }

    // 3. Détermine annulation programmée et historique payant à partir des
    // souscriptions (clé = product_id).
    let cancelAtPeriodEnd = false;
    let hadPaidSub = false;
    for (const [productId, sub] of Object.entries(subscriber.subscriptions ?? {})) {
      if (!planFromProductId(productId)) continue; // ignore produits hors plan
      hadPaidSub = true;
      if (isActive(sub.expires_date) && sub.unsubscribe_detected_at) {
        cancelAtPeriodEnd = true;
      }
    }

    const hasActivePaid = resolvedPlan !== 'free';
    // 'expired' UNIQUEMENT si un plan payant a existé puis a expiré — jamais
    // pour un utilisateur simplement sur le plan Gratuit (sinon bannière
    // « abonnement expiré » illogique).
    const status = hasActivePaid ? 'active' : hadPaidSub ? 'expired' : 'active';

    // 4. Écrit l'état réconcilié (préserve l'essai en cours géré ailleurs).
    const existing = await subRef.get();
    const existingData = existing.data();
    const isTrialOngoing =
      existingData?.status === 'trial' &&
      typeof existingData?.trialEndDate === 'string' &&
      new Date(existingData.trialEndDate).getTime() > Date.now();

    // Ne dégrade pas un essai encore valide vers "expired" si aucun achat.
    if (!hasActivePaid && isTrialOngoing) {
      return { plan: 'free', status: 'trial', cancelAtPeriodEnd: false, trial: true };
    }

    await subRef.set(
      {
        userId,
        plan: resolvedPlan,
        status,
        cancelAtPeriodEnd,
        endDate: latestExpiry,
        syncedAt: new Date().toISOString(),
      },
      { merge: true }
    );

    // 5. Aligne le badge Employeur Vérifié (réservé au plan Pro).
    await syncVerifiedBadge(db, userId, resolvedPlan === 'pro');

    logger.info('syncSubscriptionStatus', { userId, plan: resolvedPlan, status, cancelAtPeriodEnd });
    return { plan: resolvedPlan, status, cancelAtPeriodEnd, trial: false };
  }
);

async function syncVerifiedBadge(
  db: admin.firestore.Firestore,
  userId: string,
  isVerified: boolean
): Promise<void> {
  try {
    const profiles = await db
      .collection('recruiter_profiles')
      .where('userId', '==', userId)
      .get();
    await Promise.all(
      profiles.docs.map((d) => d.ref.update({ isVerifiedEmployer: isVerified }))
    );
  } catch (e) {
    logger.warn('syncVerifiedBadge échoué', e);
  }
}
