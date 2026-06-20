import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';

/**
 * Permet à l'utilisateur de confirmer "Oui c'est moi" sur une alerte de
 * sécurité. Passe par un Callable car les Security Rules interdisent au
 * client d'écrire directement dans security_flags (write: CF uniquement).
 * Retourne la sévérité du flag résolu pour que le client puisse décider
 * d'afficher l'upsell "fort" vers la Gestion d'équipe (trigger 2).
 */
export const resolveSecurityFlag = onCall(
  { region: 'europe-west1' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required.');
    }
    const { flagId } = request.data as { flagId?: string };
    if (!flagId) throw new HttpsError('invalid-argument', 'flagId requis.');

    const db = admin.firestore();
    const flagRef = db.collection('security_flags').doc(flagId);
    const flagDoc = await flagRef.get();
    if (!flagDoc.exists) {
      throw new HttpsError('not-found', 'Alerte introuvable.');
    }
    const flag = flagDoc.data()!;
    if (flag.userId !== request.auth.uid) {
      throw new HttpsError('permission-denied', 'Cette alerte ne vous appartient pas.');
    }

    await flagRef.update({
      resolved: true,
      resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { severity: flag.severity as string };
  }
);
