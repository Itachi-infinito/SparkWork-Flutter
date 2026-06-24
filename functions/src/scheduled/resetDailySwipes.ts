import * as admin from 'firebase-admin';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { logger } from 'firebase-functions/v2';

/**
 * Réinitialise à minuit UTC les quotas de swipes des recruteurs dont
 * le compteur n'a pas été remis à zéro côté client (app fermée, connexion
 * perdue, etc.). Garantit que personne ne démarre la journée avec un
 * quota bloqué par un compteur périmé.
 */
export const resetDailySwipes = onSchedule(
  { schedule: '0 0 * * *', region: 'europe-west1', timeZone: 'UTC' },
  async () => {
    const db = admin.firestore();
    const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();

    const snap = await db
      .collection('swipe_quotas')
      .where('resetAt', '<', cutoff)
      .get();

    if (snap.empty) {
      logger.info('resetDailySwipes: nothing to reset');
      return;
    }

    for (let i = 0; i < snap.docs.length; i += 400) {
      const batch = db.batch();
      for (const doc of snap.docs.slice(i, i + 400)) {
        batch.update(doc.ref, { used: 0, resetAt: new Date().toISOString() });
      }
      await batch.commit();
    }

    logger.info(`resetDailySwipes: reset ${snap.size} quota(s)`);
  }
);
