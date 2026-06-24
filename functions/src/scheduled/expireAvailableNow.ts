import * as admin from 'firebase-admin';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { logger } from 'firebase-functions/v2';

/**
 * Expire automatiquement les profils candidats en mode "Disponible
 * Maintenant" dont la date de fin (availableNowUntil) est dépassée.
 * Sans cette fonction, le badge reste allumé indéfiniment même quand
 * le candidat n'est plus disponible — les recruteurs contactent des
 * profils qui ne sont pas/plus disponibles.
 */
export const expireAvailableNow = onSchedule(
  { schedule: 'every 60 minutes', region: 'europe-west1', timeZone: 'UTC' },
  async () => {
    const db = admin.firestore();
    const now = new Date().toISOString();

    const snap = await db
      .collection('candidate_profiles')
      .where('isAvailableNow', '==', true)
      .where('availableNowUntil', '<', now)
      .get();

    if (snap.empty) {
      logger.info('expireAvailableNow: nothing to expire');
      return;
    }

    for (let i = 0; i < snap.docs.length; i += 400) {
      const batch = db.batch();
      for (const doc of snap.docs.slice(i, i + 400)) {
        batch.update(doc.ref, {
          isAvailableNow: false,
          availableNowUntil: null,
        });
      }
      await batch.commit();
    }

    logger.info(`expireAvailableNow: expired ${snap.size} profile(s)`);
  }
);
