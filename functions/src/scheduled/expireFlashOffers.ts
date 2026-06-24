import * as admin from 'firebase-admin';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { logger } from 'firebase-functions/v2';

/**
 * Ferme automatiquement les offres Flash dont flashEndDate est dépassé.
 * Sans cette fonction, l'offre reste visible côté candidat et dans la
 * liste recruteur avec un countdown à zéro — état incohérent.
 * On passe isActive à false plutôt que de supprimer pour conserver
 * l'historique et les matches existants.
 */
export const expireFlashOffers = onSchedule(
  { schedule: 'every 30 minutes', region: 'europe-west1', timeZone: 'UTC' },
  async () => {
    const db = admin.firestore();
    const now = new Date().toISOString();

    const snap = await db
      .collection('job_offers')
      .where('isFlash', '==', true)
      .where('isActive', '==', true)
      .where('flashEndDate', '<', now)
      .get();

    if (snap.empty) {
      logger.info('expireFlashOffers: nothing to expire');
      return;
    }

    for (let i = 0; i < snap.docs.length; i += 400) {
      const batch = db.batch();
      for (const doc of snap.docs.slice(i, i + 400)) {
        batch.update(doc.ref, {
          isActive: false,
          expiredAt: now,
        });
      }
      await batch.commit();
    }

    logger.info(`expireFlashOffers: closed ${snap.size} flash offer(s)`);
  }
);
