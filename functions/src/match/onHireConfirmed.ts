import * as admin from 'firebase-admin';
import { onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { sendPushToUser } from '../utils/sendPush';
import { movePipelineCardForMatch } from '../utils/movePipelineCard';

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

    const matchId = event.params.matchId;
    const db = admin.firestore();

    const wasConfirmed = before.hiredByCandidate === true && before.hiredByRecruiter === true;
    const isConfirmed = after.hiredByCandidate === true && after.hiredByRecruiter === true;

    if (!wasConfirmed && isConfirmed) {
      const hiredAt = new Date().toISOString();
      await db.collection('matches').doc(matchId).update({ hiredAt });
      await movePipelineCardForMatch(db, after.recruiterUserId, matchId, 'hired');

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
      return;
    }

    // Une seule partie vient de confirmer — prévenir l'autre qu'une
    // confirmation est en attente, sinon elle n'a aucun moyen de le
    // savoir sans rouvrir la conversation par hasard.
    const recruiterJustConfirmed = !before.hiredByRecruiter && after.hiredByRecruiter && !after.hiredByCandidate;
    const candidateJustConfirmed = !before.hiredByCandidate && after.hiredByCandidate && !after.hiredByRecruiter;

    if (recruiterJustConfirmed) {
      await sendPushToUser(
        after.candidateUserId,
        { title: 'Confirmation d\'embauche en attente', body: 'Le recruteur a confirmé votre embauche — confirmez à votre tour pour valider.' },
        { type: 'hire_pending_confirmation', matchId }
      );
    } else if (candidateJustConfirmed) {
      await sendPushToUser(
        after.recruiterUserId,
        { title: 'Confirmation d\'embauche en attente', body: 'Le candidat a confirmé l\'embauche — confirmez à votre tour pour valider.' },
        { type: 'hire_pending_confirmation', matchId }
      );
    }
  }
);
