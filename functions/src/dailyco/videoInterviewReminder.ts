import * as admin from 'firebase-admin';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { logger } from 'firebase-functions/v2';
import { sendPushToUser } from '../utils/sendPush';

const MIN_MS = 60 * 1000;

/**
 * Toutes les 5 minutes, cherche les entretiens confirmés (interviews,
 * status == 'accepted') avec un lien de réunion renseigné et dont
 * acceptedSlot tombe entre 25 et 35 minutes dans le futur, puis envoie un
 * rappel aux deux parties. reminderSent empêche tout renvoi.
 */
export const videoInterviewReminder = onSchedule(
  { schedule: 'every 5 minutes', region: 'europe-west1', timeZone: 'Europe/Brussels' },
  async () => {
    const db = admin.firestore();
    const now = Date.now();
    const windowStart = new Date(now + 25 * MIN_MS).toISOString();
    const windowEnd = new Date(now + 35 * MIN_MS).toISOString();

    // Filtre uniquement sur acceptedSlot (range simple, pas d'index composite
    // requis) — les entretiens non acceptés ont acceptedSlot == '' qui ne
    // matche jamais une fenêtre ISO non vide, donc le filtre status est
    // redondant mais vérifié en mémoire par sécurité.
    const snap = await db
      .collection('interviews')
      .where('acceptedSlot', '>=', windowStart)
      .where('acceptedSlot', '<=', windowEnd)
      .get();

    if (snap.empty) return;

    for (const doc of snap.docs) {
      const interview = doc.data();
      if (interview.status !== 'accepted' || interview.reminderSent === true || !interview.meetingLink) continue;

      await Promise.all([
        sendPushToUser(interview.candidateUserId, {
          title: 'Entretien dans 30 minutes',
          body: 'N\'oubliez pas votre entretien vidéo programmé.',
        }, { type: 'video_interview', matchId: interview.matchId }),
        sendPushToUser(interview.recruiterUserId, {
          title: 'Entretien dans 30 minutes',
          body: 'N\'oubliez pas votre entretien vidéo programmé.',
        }, { type: 'video_interview', matchId: interview.matchId }),
      ]);
      await doc.ref.update({ reminderSent: true });
    }

    logger.info(`Video interview reminders sent for ${snap.size} interview(s)`);
  }
);
