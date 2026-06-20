import * as admin from 'firebase-admin';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { logger } from 'firebase-functions/v2';
import { sendPushToUser } from '../utils/sendPush';

const HOUR_MS = 60 * 60 * 1000;

/**
 * Toutes les heures, cherche les matches embauchés entre 71h et 73h dans le
 * passé (fenêtre de 2h pour absorber le délai entre deux exécutions sans
 * créer de doublons) et envoie un rappel de notation aux deux parties.
 * ratingReminderSentAt empêche tout renvoi.
 */
export const ratingReminder = onSchedule(
  { schedule: 'every 60 minutes', region: 'europe-west1', timeZone: 'Europe/Brussels' },
  async () => {
    const db = admin.firestore();
    const now = Date.now();
    const windowStart = new Date(now - 73 * HOUR_MS).toISOString();
    const windowEnd = new Date(now - 71 * HOUR_MS).toISOString();

    // hiredAt est une string ISO8601 — les comparaisons lexicographiques
    // correspondent à l'ordre chronologique tant que le format est fixe (UTC).
    const snap = await db
      .collection('matches')
      .where('hiredAt', '>=', windowStart)
      .where('hiredAt', '<=', windowEnd)
      .get();

    if (snap.empty) return;

    for (const doc of snap.docs) {
      const match = doc.data();
      if (match.ratingReminderSentAt) continue;

      const [candidateSnap, recruiterSnap] = await Promise.all([
        db
          .collection('candidate_profiles')
          .where('userId', '==', match.candidateUserId)
          .limit(1)
          .get(),
        db
          .collection('recruiter_profiles')
          .where('userId', '==', match.recruiterUserId)
          .limit(1)
          .get(),
      ]);

      const candidateName = (candidateSnap.docs[0]?.data()?.fullName as string) || 'ce candidat';
      const companyName = (recruiterSnap.docs[0]?.data()?.companyName as string) || 'cet employeur';

      try {
        await Promise.all([
          sendPushToUser(
            match.candidateUserId,
            {
              title: 'Comment ça s\'est passé ?',
              body: `Laissez un avis sur votre collaboration avec ${companyName} en 30 secondes.`,
            },
            {
              type: 'rating_reminder',
              matchId: doc.id,
              targetUserId: match.recruiterUserId,
              targetName: companyName,
              isRecruiter: 'false',
            }
          ),
          sendPushToUser(
            match.recruiterUserId,
            {
              title: 'Comment ça s\'est passé ?',
              body: `Laissez un avis sur votre collaboration avec ${candidateName} en 30 secondes.`,
            },
            {
              type: 'rating_reminder',
              matchId: doc.id,
              targetUserId: match.candidateUserId,
              targetName: candidateName,
              isRecruiter: 'true',
            }
          ),
        ]);

        await doc.ref.update({
          ratingReminderSentAt: new Date().toISOString(),
        });
      } catch (e) {
        logger.error(`ratingReminder failed for match ${doc.id}`, e);
      }
    }
  }
);
