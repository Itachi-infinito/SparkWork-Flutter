import * as admin from 'firebase-admin';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions/v2';
import { sendPushToUser } from '../utils/sendPush';

const WINDOW_DAYS = 7;
const MIN_DISTINCT_RECRUITERS = 3;
const ALERT_COOLDOWN_HOURS = 24;

/**
 * Alerte concurrence en temps réel : quand un candidat est retenu ("retain"
 * ou "favorite") par un 3ème recruteur distinct dans les 7 derniers jours,
 * prévient chaque recruteur l'ayant DÉJÀ retenu — "agissez maintenant,
 * ce candidat est convoité". Max 1 alerte par candidat par recruteur / 24h.
 */
export const onSwipeVoteWritten = onDocumentWritten(
  { document: 'swipe_votes/{voteId}', region: 'europe-west1' },
  async (event) => {
    const after = event.data?.after?.data();
    if (!after || (after.vote !== 'retain' && after.vote !== 'favorite')) return;

    const candidateId = after.candidateId as string;
    if (!candidateId) return;

    const db = admin.firestore();
    const since = new Date(Date.now() - WINDOW_DAYS * 24 * 60 * 60 * 1000).toISOString();

    const snap = await db
      .collection('swipe_votes')
      .where('candidateId', '==', candidateId)
      .where('createdAt', '>=', since)
      .get();

    const retainedBy = snap.docs.filter(
      (d) => d.data().vote === 'retain' || d.data().vote === 'favorite'
    );

    // Un recruteur = un voterId distinct (pas un teamId — deux membres de la
    // même équipe qui retiennent le même candidat ne comptent qu'une fois
    // dans l'intention, mais on garde simple : chaque voterId est un recruteur).
    const distinctVoterIds = new Set(retainedBy.map((d) => d.data().voterId as string));
    if (distinctVoterIds.size < MIN_DISTINCT_RECRUITERS) return;

    const candidateNameSnap = await db
      .collection('candidate_profiles')
      .where('userId', '==', candidateId)
      .limit(1)
      .get();
    const candidateName = candidateNameSnap.docs[0]?.data()?.fullName as string | undefined;

    const cooldownCutoff = Date.now() - ALERT_COOLDOWN_HOURS * 60 * 60 * 1000;

    for (const doc of retainedBy) {
      const voterId = doc.data().voterId as string;
      const lastAlertMs = doc.data().lastCompetitionAlertAt as number | undefined;
      if (lastAlertMs && lastAlertMs > cooldownCutoff) continue; // déjà alerté récemment

      await sendPushToUser(
        voterId,
        {
          title: '⚡ Candidat très sollicité',
          body: `${candidateName ?? 'Ce candidat'} est très sollicité — ${distinctVoterIds.size} `
            + 'recruteurs l\'ont retenu récemment. Agissez maintenant !',
        },
        { type: 'competition_alert', candidateId }
      );

      await doc.ref.update({ lastCompetitionAlertAt: Date.now() });
    }

    logger.info('Competition alert evaluated', {
      candidateId,
      distinctRecruiters: distinctVoterIds.size,
    });
  }
);
