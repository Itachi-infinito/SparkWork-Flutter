import * as admin from 'firebase-admin';
import * as crypto from 'crypto';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';
import { sendEmail } from '../utils/email';
import { otpUnlockEmail } from '../utils/emailTemplates';

const OTP_TTL_MINUTES = 10;

function hashCode(code: string): string {
  return crypto.createHash('sha256').update(code).digest('hex');
}

export const requestRestrictedUnlockOtp = onCall(
  { region: 'europe-west1', enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required.');
    }
    const userId = request.auth.uid;
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = Date.now() + OTP_TTL_MINUTES * 60 * 1000;

    const db = admin.firestore();
    await db.collection('security_otps').doc(userId).set({
      userId,
      codeHash: hashCode(code),
      expiresAt,
      consumed: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Récupère l'email de l'utilisateur depuis Firebase Auth
    const userRecord = await admin.auth().getUser(userId);
    const email = userRecord.email;
    if (!email) {
      logger.error(`requestRestrictedUnlockOtp: no email for user ${userId}`);
      throw new HttpsError('internal', 'Impossible d\'envoyer le code — email manquant.');
    }

    await sendEmail(
      email,
      `Votre code de déblocage SparkWork : ${code}`,
      otpUnlockEmail(code, OTP_TTL_MINUTES)
    );

    return { sent: true };
  }
);

export const verifyRestrictedUnlockOtp = onCall(
  { region: 'europe-west1', enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required.');
    }
    const userId = request.auth.uid;
    const { code } = request.data as { code?: string };
    if (!code) throw new HttpsError('invalid-argument', 'Code requis.');

    const db = admin.firestore();
    const otpRef = db.collection('security_otps').doc(userId);
    const otpDoc = await otpRef.get();
    if (!otpDoc.exists) {
      throw new HttpsError('not-found', 'Aucune demande de déblocage en cours.');
    }
    const otp = otpDoc.data()!;
    if (otp.consumed) {
      throw new HttpsError('failed-precondition', 'Ce code a déjà été utilisé.');
    }
    if (Date.now() > otp.expiresAt) {
      throw new HttpsError('deadline-exceeded', 'Ce code a expiré, demandez-en un nouveau.');
    }
    if (otp.codeHash !== hashCode(code)) {
      throw new HttpsError('invalid-argument', 'Code incorrect.');
    }

    await otpRef.update({ consumed: true });
    await db.collection('users').doc(userId).set(
      {
        isRestricted: false,
        restrictedAt: null,
      },
      { merge: true }
    );

    return { unlocked: true };
  }
);

/**
 * Déblocage manuel par un administrateur depuis le dashboard sécurité —
 * sans passer par l'OTP email (utile si l'utilisateur ne peut pas le
 * recevoir, ou en cas de faux positif manifeste).
 */
export const adminUnlockRestrictedAccount = onCall(
  { region: 'europe-west1', enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required.');
    }
    const db = admin.firestore();
    const callerDoc = await db.collection('users').doc(request.auth.uid).get();
    if (callerDoc.data()?.isAdmin !== true) {
      throw new HttpsError('permission-denied', 'Réservé aux administrateurs.');
    }

    const { userId } = request.data as { userId?: string };
    if (!userId) throw new HttpsError('invalid-argument', 'userId requis.');

    await db.collection('users').doc(userId).set(
      { isRestricted: false, restrictedAt: null },
      { merge: true }
    );

    return { unlocked: true };
  }
);
