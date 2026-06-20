import * as admin from 'firebase-admin';
import { onRequest } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';
import * as crypto from 'crypto';

const STATUS_MAP: Record<string, string> = {
  'identity.verification_session.verified': 'verified',
  'identity.verification_session.requires_input': 'rejected',
};

/**
 * Vérifie la signature Stripe selon leur schéma documenté :
 * header "Stripe-Signature: t=<timestamp>,v1=<signature>"
 * signature attendue = HMAC-SHA256(secret, `${timestamp}.${rawBody}`)
 */
function verifyStripeSignature(rawBody: string, header: string, secret: string): boolean {
  const parts = Object.fromEntries(
    header.split(',').map((p) => p.split('=') as [string, string])
  );
  const timestamp = parts.t;
  const signature = parts.v1;
  if (!timestamp || !signature) return false;

  const expected = crypto
    .createHmac('sha256', secret)
    .update(`${timestamp}.${rawBody}`)
    .digest('hex');
  try {
    return crypto.timingSafeEqual(Buffer.from(expected, 'hex'), Buffer.from(signature, 'hex'));
  } catch {
    return false;
  }
}

/**
 * ⚠️ Nécessite STRIPE_WEBHOOK_SECRET (depuis le dashboard Stripe, section
 * Webhooks) — non fonctionnel tant que le compte Stripe Identity n'est
 * pas configuré, comme pour le webhook Veriff.
 */
export const stripeIdentityWebhook = onRequest(
  { region: 'europe-west1' },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }

    const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET ?? '';
    if (!webhookSecret) {
      logger.error('STRIPE_WEBHOOK_SECRET not set');
      res.status(500).send('Webhook not configured');
      return;
    }

    const signatureHeader = req.headers['stripe-signature'] as string | undefined;
    if (!signatureHeader) {
      res.status(401).send('Missing signature');
      return;
    }

    const rawBody = JSON.stringify(req.body);
    if (!verifyStripeSignature(rawBody, signatureHeader, webhookSecret)) {
      logger.warn('Invalid Stripe webhook signature');
      res.status(401).send('Invalid signature');
      return;
    }

    const { type, data } = req.body as {
      type: string;
      data: { object: { id: string; metadata?: { userId?: string }; last_error?: { reason?: string } } };
    };

    logger.info('Stripe Identity webhook', { type, sessionId: data?.object?.id });

    const ourStatus = STATUS_MAP[type];
    if (!ourStatus) {
      res.status(200).send('OK');
      return;
    }

    const userId = data.object.metadata?.userId;
    if (!userId) {
      res.status(400).send('Missing metadata.userId');
      return;
    }

    const db = admin.firestore();
    const now = admin.firestore.FieldValue.serverTimestamp();
    const declineReason = data.object.last_error?.reason ?? null;

    await db.collection('verifications').doc(userId).update({
      status: ourStatus,
      declineReason,
      decidedAt: now,
      sessionId: data.object.id,
    });

    const profileSnap = await db
      .collection('candidate_profiles')
      .where('userId', '==', userId)
      .limit(1)
      .get();

    if (!profileSnap.empty) {
      await profileSnap.docs[0].ref.update({
        verificationStatus: ourStatus,
        verificationDate: new Date().toISOString(),
        verificationRejectionReason: declineReason,
      });
    }

    res.status(200).send('OK');
  }
);
