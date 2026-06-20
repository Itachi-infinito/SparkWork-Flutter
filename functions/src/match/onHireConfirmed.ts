import * as admin from 'firebase-admin';
import { onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { sendPushToUser } from '../utils/sendPush';

/**
 * Déclenché à chaque update d'un match. Quand les deux parties viennent de
 * confirmer l'embauche (transition false→true sur les deux flags), on
 * horodate hiredAt côté serveur (source de vérité unique) et on notifie
 * les deux utilisateurs. hiredAt est stocké en ISO8601 string, comme le
 * reste des champs de date de l'app (createdAt, etc.) pour rester
 * compatible avec Match.fromMap côté Flutter.
 */
export const onHireConfirmed = onDocumentUpdated(
  { document: 'matches/{matchId}', region: 'europe-west1' },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const wasConfirmed = before.hiredByCandidate === true && before.hiredByRecruiter === true;
    const isConfirmed = after.hiredByCandidate === true && after.hiredByRecruiter === true;

    if (wasConfirmed || !isConfirmed) return;

    const matchId = event.params.matchId;
    const db = admin.firestore();
    const hiredAt = new Date().toISOString();

    await db.collection('matches').doc(matchId).update({ hiredAt });

    await Promise.all([
      sendPushToUser(
        after.candidateUserId,
        { title: 'Félicitations !', body: "L'embauche a été confirmée." },
        { type: 'hire_confirmed', matchId }
      ),
      sendPushToUser(
        after.recruiterUserId,
        { title: 'Félicitations !', body: "L'embauche a été confirmée." },
        { type: 'hire_confirmed', matchId }
      ),
    ]);
  }
);
