import * as admin from 'firebase-admin';
import { logger } from 'firebase-functions/v2';

/**
 * Envoie une notification push à un utilisateur via son fcmToken
 * (stocké dans users/{userId}.fcmToken par NotificationService côté Flutter).
 * Échoue silencieusement si l'utilisateur n'a pas de token — un push
 * manqué ne doit jamais faire échouer le flux métier qui l'a déclenché.
 */
export async function sendPushToUser(
  userId: string,
  notification: { title: string; body: string },
  data: Record<string, string> = {}
): Promise<void> {
  try {
    const db = admin.firestore();
    const userDoc = await db.collection('users').doc(userId).get();
    const token = userDoc.data()?.fcmToken as string | undefined;
    if (!token) return;

    await admin.messaging().send({
      token,
      notification,
      data,
    });
  } catch (e) {
    logger.error(`sendPushToUser failed for ${userId}`, e);
  }
}
