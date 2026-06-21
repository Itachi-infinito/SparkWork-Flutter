import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';

/**
 * Droit à l'effacement RGPD : supprime tous les logs de sécurité de
 * l'utilisateur courant (security_logs/{uid}/events/*). Accessible depuis
 * les paramètres du compte. Le client ne peut pas le faire lui-même —
 * security_logs n'est lisible/écrivable que par les Cloud Functions.
 */
export const deleteMySecurityLogs = onCall(
  { region: 'europe-west1', enforceAppCheck: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required.');
    }
    const userId = request.auth.uid;
    const db = admin.firestore();
    const snap = await db.collection('security_logs').doc(userId).collection('events').get();

    for (let i = 0; i < snap.docs.length; i += 400) {
      const batch = db.batch();
      for (const doc of snap.docs.slice(i, i + 400)) {
        batch.delete(doc.ref);
      }
      await batch.commit();
    }

    return { deletedCount: snap.size };
  }
);
