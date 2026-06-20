import * as admin from 'firebase-admin';
import { onRequest } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';
import { sendPushToUser } from '../utils/sendPush';

type RevenueCatEventType =
  | 'INITIAL_PURCHASE'
  | 'RENEWAL'
  | 'PRODUCT_CHANGE'
  | 'UNCANCELLATION'
  | 'CANCELLATION'
  | 'EXPIRATION'
  | 'BILLING_ISSUE'
  | string;

interface RevenueCatEvent {
  type: RevenueCatEventType;
  app_user_id: string;
  product_id?: string;
  expiration_at_ms?: number;
  purchased_at_ms?: number;
  environment?: 'SANDBOX' | 'PRODUCTION';
}

const PRODUCT_TO_PLAN: Record<string, string> = {
  sparkwork_starter_monthly: 'starter',
  sparkwork_pro_monthly: 'pro',
};

function planFromProductId(productId: string | undefined): string | null {
  if (!productId) return null;
  return PRODUCT_TO_PLAN[productId] ?? null;
}

export const receiveRevenueCatWebhook = onRequest(
  { region: 'europe-west1' },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }

    // RevenueCat envoie un secret partagé dans l'en-tête Authorization
    // (configuré dans RevenueCat Dashboard > Integrations > Webhooks).
    const expectedAuth = process.env.REVENUECAT_WEBHOOK_SECRET ?? '';
    const receivedAuth = req.headers['authorization'] as string | undefined;
    if (!expectedAuth || receivedAuth !== `Bearer ${expectedAuth}`) {
      logger.warn('RevenueCat webhook: invalid or missing Authorization header');
      res.status(401).send('Unauthorized');
      return;
    }

    const event = req.body?.event as RevenueCatEvent | undefined;
    if (!event?.app_user_id || !event?.type) {
      res.status(400).send('Malformed event');
      return;
    }

    const userId = event.app_user_id;
    const db = admin.firestore();
    const subRef = db.collection('recruiter_subscriptions').doc(userId);

    logger.info('RevenueCat webhook', { type: event.type, userId, productId: event.product_id });

    try {
      switch (event.type) {
        case 'INITIAL_PURCHASE':
        case 'UNCANCELLATION':
        case 'PRODUCT_CHANGE': {
          const plan = planFromProductId(event.product_id);
          if (!plan) {
            logger.warn(`Unknown product_id: ${event.product_id}`);
            break;
          }
          await subRef.set(
            {
              userId,
              plan,
              status: 'active',
              cancelAtPeriodEnd: false,
              startDate: event.purchased_at_ms
                ? new Date(event.purchased_at_ms).toISOString()
                : new Date().toISOString(),
              endDate: event.expiration_at_ms
                ? new Date(event.expiration_at_ms).toISOString()
                : null,
            },
            { merge: true }
          );

          // Met à jour le badge Employeur Vérifié pour le plan Pro
          await _syncVerifiedBadge(db, userId, plan === 'pro');
          break;
        }

        case 'RENEWAL': {
          await subRef.set(
            {
              status: 'active',
              cancelAtPeriodEnd: false,
              endDate: event.expiration_at_ms
                ? new Date(event.expiration_at_ms).toISOString()
                : null,
            },
            { merge: true }
          );
          break;
        }

        case 'CANCELLATION': {
          // L'accès reste actif jusqu'à la fin de la période déjà payée —
          // seul le renouvellement automatique est désactivé.
          await subRef.set({ cancelAtPeriodEnd: true }, { merge: true });
          break;
        }

        case 'EXPIRATION': {
          await subRef.set(
            { status: 'expired', cancelAtPeriodEnd: false },
            { merge: true }
          );
          await _syncVerifiedBadge(db, userId, false);
          break;
        }

        case 'BILLING_ISSUE': {
          await sendPushToUser(userId, {
            title: 'Problème de paiement',
            body: 'Mettez à jour vos informations de paiement pour continuer à profiter de votre abonnement.',
          });
          break;
        }

        default:
          logger.info(`Unhandled RevenueCat event type: ${event.type}`);
      }

      res.status(200).send('OK');
    } catch (e) {
      logger.error('RevenueCat webhook processing failed', e);
      res.status(500).send('Internal error');
    }
  }
);

async function _syncVerifiedBadge(
  db: admin.firestore.Firestore,
  userId: string,
  isVerified: boolean
): Promise<void> {
  const profiles = await db
    .collection('recruiter_profiles')
    .where('userId', '==', userId)
    .get();
  await Promise.all(
    profiles.docs.map((d) => d.ref.update({ isVerifiedEmployer: isVerified }))
  );
}
