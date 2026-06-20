import * as admin from 'firebase-admin';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { logger } from 'firebase-functions/v2';

const RETENTION_DAYS = 90;

/**
 * Supprime automatiquement les logs de sécurité (security_logs/*\/events)
 * de plus de 90 jours, conformément à la politique de rétention RGPD
 * annoncée dans la politique de confidentialité.
 */
export const cleanupSecurityLogs = onSchedule(
  { schedule: 'every 24 hours', region: 'europe-west1', timeZone: 'Europe/Brussels' },
  async () => {
    const db = admin.firestore();
    const cutoff = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - RETENTION_DAYS * 24 * 60 * 60 * 1000)
    );

    const snap = await db
      .collectionGroup('events')
      .where('createdAt', '<', cutoff)
      .get();

    if (snap.empty) {
      logger.info('cleanupSecurityLogs: nothing to delete');
      return;
    }

    for (let i = 0; i < snap.docs.length; i += 400) {
      const batch = db.batch();
      for (const doc of snap.docs.slice(i, i + 400)) {
        batch.delete(doc.ref);
      }
      await batch.commit();
    }

    logger.info(`cleanupSecurityLogs: deleted ${snap.size} events older than ${RETENTION_DAYS} days`);
  }
);
