import * as admin from 'firebase-admin';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { sendPushToUser } from '../utils/sendPush';
import { movePipelineCardForMatch } from '../utils/movePipelineCard';

/**
 * Notifie les deux parties des changements sur une proposition
 * d'entretien — jusqu'ici purement silencieux (écriture Firestore sans
 * notification), obligeant chacun à rouvrir la conversation par hasard
 * pour découvrir qu'une action de l'autre partie l'attend.
 */
export const onInterviewWritten = onDocumentWritten(
  { document: 'interviews/{interviewId}', region: 'europe-west1' },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!after) return; // suppression — rien à notifier

    const matchId = after.matchId as string;

    // Nouvelle proposition (création, ou re-proposition après refus —
    // détectée par un statut qui redevient 'pending').
    const isNewProposal = !before || (before.status !== 'pending' && after.status === 'pending');
    if (isNewProposal) {
      await sendPushToUser(
        after.candidateUserId,
        { title: 'Proposition d\'entretien', body: 'Un recruteur vous propose un entretien — choisissez un créneau.' },
        { type: 'interview_proposed', matchId }
      );
      return;
    }

    if (!before) return;

    if (before.status === 'pending' && after.status === 'accepted') {
      await movePipelineCardForMatch(admin.firestore(), after.recruiterUserId, matchId, 'interview_scheduled');
      await sendPushToUser(
        after.recruiterUserId,
        { title: 'Entretien confirmé', body: 'Le candidat a confirmé un créneau d\'entretien.' },
        { type: 'interview_accepted', matchId }
      );
    } else if (before.status === 'pending' && after.status === 'declined') {
      await sendPushToUser(
        after.recruiterUserId,
        { title: 'Entretien refusé', body: 'Le candidat a refusé la proposition d\'entretien.' },
        { type: 'interview_declined', matchId }
      );
    }
  }
);
