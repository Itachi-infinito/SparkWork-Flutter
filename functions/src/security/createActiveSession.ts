import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';
import { sendPushToUser } from '../utils/sendPush';
import { lookupCountry } from './geoLookup';
import { checkAnomaliesAfterSession } from './analyzeSessionAnomaly';

/**
 * Crée une session active pour l'utilisateur courant. Passe par un Callable
 * (plutôt qu'une écriture Firestore directe côté client) pour pouvoir
 * capturer l'adresse IP côté serveur — elle n'est jamais exposée au client
 * ni stockée ailleurs que dans ce document, utilisée uniquement pour la
 * détection d'anomalies et supprimée automatiquement après 90 jours.
 *
 * Invalide aussi, dans la même opération, toute session active sur un AUTRE
 * appareil (session unique par appareil) et notifie son propriétaire.
 */
export const createActiveSession = onCall(
  { region: 'europe-west1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required.');
    }
    const userId = request.auth.uid;
    const { deviceId, deviceModel, deviceOS, appVersion } = request.data as {
      deviceId?: string;
      deviceModel?: string;
      deviceOS?: string;
      appVersion?: string;
    };
    if (!deviceId) {
      throw new HttpsError('invalid-argument', 'deviceId requis.');
    }

    const forwardedFor = request.rawRequest.headers['x-forwarded-for'];
    const ipAddress =
      (typeof forwardedFor === 'string' ? forwardedFor.split(',')[0].trim() : undefined) ??
      request.rawRequest.ip ??
      '';
    const country = await lookupCountry(ipAddress);

    const db = admin.firestore();
    const now = new Date();
    const sessionRef = db.collection('active_sessions').doc();
    await sessionRef.set({
      userId,
      deviceId,
      deviceModel: deviceModel ?? 'Appareil inconnu',
      deviceOS: deviceOS ?? '',
      appVersion: appVersion ?? '',
      loginAt: now.toISOString(),
      lastActiveAt: now.toISOString(),
      isActive: true,
      ipAddress,
      country,
    });

    // Session unique par appareil : invalide les autres sessions actives.
    const others = await db
      .collection('active_sessions')
      .where('userId', '==', userId)
      .where('isActive', '==', true)
      .get();

    let invalidatedOtherDevice = false;
    for (const doc of others.docs) {
      if (doc.id === sessionRef.id) continue;
      const other = doc.data();
      if (other.deviceId === deviceId) {
        await doc.ref.update({ isActive: false, logoutReason: 'expired' });
      } else {
        await doc.ref.update({ isActive: false, logoutReason: 'new_session' });
        invalidatedOtherDevice = true;
      }
    }

    if (invalidatedOtherDevice) {
      await sendPushToUser(userId, {
        title: 'Nouvelle connexion détectée',
        body:
          'Votre compte a été ouvert sur un nouvel appareil. Vous avez été ' +
          'déconnecté automatiquement pour protéger votre compte. Si ce ' +
          'n\'est pas vous, changez votre mot de passe immédiatement.',
      });
      await db.collection('security_logs').doc(userId).collection('events').add({
        type: 'new_device_login',
        deviceModel: deviceModel ?? '',
        deviceOS: deviceOS ?? '',
        loginAt: now.toISOString(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    try {
      await checkAnomaliesAfterSession(db, userId, deviceId, deviceOS ?? '', country);
    } catch (e) {
      // La détection d'anomalies ne doit jamais faire échouer la connexion.
      logger.error('Anomaly detection failed', e);
    }

    return { sessionId: sessionRef.id };
  }
);
