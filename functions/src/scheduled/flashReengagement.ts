import * as admin from 'firebase-admin';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { logger } from 'firebase-functions/v2';
import { sendPushToUser } from '../utils/sendPush';

/**
 * Relance Flash — toutes les 30 minutes.
 *
 * Une offre Flash qui expire dans moins de 2h sans que son recruteur ne le
 * réalise = opportunité perdue + frustration. On le prévient UNE fois
 * (flashReminderSent) avec le contexte qui pousse à agir : combien de
 * candidats ont déjà liké l'offre. Time-sensitive → envoyé même pendant
 * les heures silencieuses.
 *
 * Réutilise l'index composite de expireFlashOffers (isFlash + isActive +
 * borne sur flashEndDate) — la seconde borne sur le même champ et le filtre
 * flashReminderSent se font en mémoire pour ne pas exiger de nouvel index.
 */

export const flashReengagement = onSchedule(
  { schedule: 'every 30 minutes', region: 'europe-west1', timeZone: 'UTC' },
  async () => {
    const db = admin.firestore();
    const now = Date.now();
    const nowIso = new Date(now).toISOString();
    const cutoffIso = new Date(now + 2 * 3600 * 1000).toISOString();

    const snap = await db
      .collection('job_offers')
      .where('isFlash', '==', true)
      .where('isActive', '==', true)
      .where('flashEndDate', '<', cutoffIso)
      .get();

    const expiring = snap.docs.filter((d) => {
      const data = d.data();
      return (
        (data.flashEndDate as string) > nowIso && // pas encore expirée
        data.flashReminderSent !== true
      );
    });

    if (expiring.length === 0) return;

    let sent = 0;
    for (const offerDoc of expiring) {
      const offer = offerDoc.data();
      const recruiterId = offer.recruiterUserId as string | undefined;
      if (!recruiterId) continue;

      try {
        const likesSnap = await db
          .collection('candidate_job_likes')
          .where('jobOfferId', '==', offerDoc.id)
          .get();
        const likes = likesSnap.size;

        const remainingMin = Math.max(
          1,
          Math.round((new Date(String(offer.flashEndDate)).getTime() - now) / 60000)
        );
        const remainingLabel = remainingMin >= 60
          ? `${Math.round(remainingMin / 60)}h`
          : `${remainingMin} min`;

        const context = likes > 0
          ? `${likes} candidat${likes > 1 ? 's ont' : ' a'} déjà liké — swipez-les avant la fin !`
          : 'Un boost peut encore la mettre en avant.';

        await sendPushToUser(
          recruiterId,
          {
            title: '⏳ Offre Flash bientôt terminée',
            body: `« ${String(offer.title ?? 'Votre offre')} » expire dans ${remainingLabel}. ${context}`,
          },
          { route: '/recruiter/offers' }
        );
        await offerDoc.ref.update({ flashReminderSent: true });
        sent++;
      } catch (e) {
        logger.error(`flashReengagement failed for offer ${offerDoc.id}`, e);
      }
    }

    logger.info(`flashReengagement: ${sent} relance(s) envoyée(s)`);
  }
);
