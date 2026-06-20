import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';

// eslint-disable-next-line @typescript-eslint/no-require-imports
const fetch = require('node-fetch') as typeof import('node-fetch').default;

const VERIFF_BASE_URL = 'https://stationapi.veriff.com';
const MAX_ATTEMPTS = 3;

export const createVeriffSession = onCall(
  { region: 'europe-west1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required.');
    }

    const userId = request.auth.uid;
    const {
      documentType = 'NATIONAL_IDENTITY_CARD',
      firstName = '',
      lastName = '',
    } = request.data as {
      documentType?: string;
      firstName?: string;
      lastName?: string;
    };

    const validTypes = ['NATIONAL_IDENTITY_CARD', 'PASSPORT', 'DRIVERS_LICENSE'];
    if (!validTypes.includes(documentType)) {
      throw new HttpsError('invalid-argument', 'Invalid document type.');
    }

    const db = admin.firestore();
    const veriffDoc = await db.collection('verifications').doc(userId).get();
    const existing = veriffDoc.exists ? veriffDoc.data()! : {};
    const attemptCount: number = existing.attemptCount ?? 0;

    if (attemptCount >= MAX_ATTEMPTS) {
      throw new HttpsError(
        'resource-exhausted',
        'Maximum verification attempts reached. Please contact support.'
      );
    }

    // API key loaded from environment variable (set via .env or Firebase Console)
    const apiKey = process.env.VERIFF_API_KEY ?? '';
    if (!apiKey) {
      logger.error('VERIFF_API_KEY not set');
      throw new HttpsError('internal', 'Verification service not configured.');
    }

    const sessionPayload = {
      verification: {
        person: {
          firstName: firstName || undefined,
          lastName: lastName || undefined,
        },
        document: {
          type: documentType,
          country: 'FR',
        },
        vendorData: userId,
      },
    };

    const response = await fetch(`${VERIFF_BASE_URL}/v1/sessions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-AUTH-CLIENT': apiKey,
      },
      body: JSON.stringify(sessionPayload),
    });

    if (!response.ok) {
      const errorText = await response.text();
      logger.error('Veriff session creation failed', { errorText });
      throw new HttpsError('internal', 'Failed to create verification session.');
    }

    const result = await response.json() as {
      status: string;
      verification: { id: string; sessionToken: string; url: string };
    };

    const sessionId = result.verification.id;
    // sessionUrl is what veriff_flutter 2.x Configuration() takes
    const sessionUrl = result.verification.url;

    // Store session metadata — never the document images
    await db.collection('verifications').doc(userId).set(
      {
        userId,
        sessionId,
        status: 'pending',
        submittedAt: admin.firestore.FieldValue.serverTimestamp(),
        attemptCount: attemptCount + 1,
        documentType,
        declineReason: null,
        decidedAt: null,
      },
      { merge: true }
    );

    // Mirror status to candidate_profiles for swipe card display
    const profileSnap = await db
      .collection('candidate_profiles')
      .where('userId', '==', userId)
      .limit(1)
      .get();
    if (!profileSnap.empty) {
      await profileSnap.docs[0].ref.update({ verificationStatus: 'pending' });
    }

    return { sessionUrl, sessionId };
  }
);
