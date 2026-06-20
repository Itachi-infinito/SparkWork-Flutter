import * as admin from 'firebase-admin';
import { onRequest } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';
import * as crypto from 'crypto';

const STATUS_MAP: Record<string, string> = {
  approved: 'verified',
  declined: 'rejected',
  resubmission_requested: 'resubmission_requested',
};

function verifyHmac(rawBody: string, signature: string, secret: string): boolean {
  const expected = crypto
    .createHmac('sha256', secret)
    .update(rawBody)
    .digest('hex');
  try {
    return crypto.timingSafeEqual(
      Buffer.from(expected, 'hex'),
      Buffer.from(signature, 'hex')
    );
  } catch {
    return false;
  }
}

export const veriffWebhook = onRequest(
  { region: 'europe-west1' },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }

    const webhookSecret = process.env.VERIFF_WEBHOOK_SECRET ?? '';
    if (!webhookSecret) {
      logger.error('VERIFF_WEBHOOK_SECRET not set');
      res.status(500).send('Webhook not configured');
      return;
    }

    const signature = req.headers['x-hmac-signature'] as string | undefined;
    if (!signature) {
      res.status(401).send('Missing signature');
      return;
    }

    const rawBody = JSON.stringify(req.body);
    if (!verifyHmac(rawBody, signature, webhookSecret)) {
      logger.warn('Invalid webhook signature');
      res.status(401).send('Invalid signature');
      return;
    }

    const { action, verification } = req.body as {
      action: string;
      verification: {
        id: string;
        vendorData: string;
        reason?: string;
      };
    };

    logger.info('Veriff webhook', { action, sessionId: verification?.id });

    const ourStatus = STATUS_MAP[action];
    if (!ourStatus) {
      res.status(200).send('OK');
      return;
    }

    const userId = verification.vendorData;
    if (!userId) {
      res.status(400).send('Missing vendorData');
      return;
    }

    const db = admin.firestore();
    const now = admin.firestore.FieldValue.serverTimestamp();
    const declineReason = verification.reason ?? null;

    await db.collection('verifications').doc(userId).update({
      status: ourStatus,
      declineReason,
      decidedAt: now,
      sessionId: verification.id,
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
