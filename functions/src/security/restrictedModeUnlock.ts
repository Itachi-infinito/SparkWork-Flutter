import * as admin from 'firebase-admin';
import * as crypto from 'crypto';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';

const OTP_TTL_MINUTES = 10;

function hashCode(code: string): string {
  return crypto.createHash('sha256').update(code).digest('hex');
}

/**
 * Génère un code à 6 chiffres pour débloquer un compte en mode restreint.
 *
 * TODO: aucun fournisseur d'emailing n'est configuré (SendGrid/Mailgun...).
 * Le code est actuellement journalisé via logger.info ET retourné dans la
 * réponse pour permettre les tests de bout en bout — RETIRER le code de la
 * réponse dès qu'un envoi d'email réel est branché, sans quoi n'importe qui
 * avec le token d'auth de l'utilisateur peut se débloquer sans jamais lire
 * son email.
 */
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

    logger.info(`Unlock OTP for ${userId}: ${code} (expires in ${OTP_TTL_MINUTES} min)`);

    return {
      sent: true,
      // TODO: retirer une fois l'envoi d'email réel branché.
      devOnlyCode: code,
    };
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
