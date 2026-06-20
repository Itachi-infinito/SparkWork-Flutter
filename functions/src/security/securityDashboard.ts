import * as admin from 'firebase-admin';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { logger } from 'firebase-functions/v2';

const MIN_STARTER_PRICE_EUR = 49;

/**
 * Agrège quotidiennement des métriques de sécurité dans
 * security_dashboard/latest, consultées par l'écran admin. Toutes les
 * métriques sont des heuristiques de détection de partage de compte —
 * jamais des certitudes, jamais utilisées pour bloquer automatiquement.
 */
export const aggregateSecurityDashboard = onSchedule(
  { schedule: 'every 24 hours', region: 'europe-west1', timeZone: 'Europe/Brussels' },
  async () => {
    const db = admin.firestore();
    const since30d = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();

    const [sessionsSnap, flagsSnap, restrictedSnap] = await Promise.all([
      db.collection('active_sessions').where('loginAt', '>=', since30d).get(),
      db.collection('security_flags').get(),
      db.collection('users').where('isRestricted', '==', true).get(),
    ]);

    const devicesByUser = new Map<string, Set<string>>();
    for (const doc of sessionsSnap.docs) {
      const data = doc.data();
      const userId = data.userId as string;
      const deviceId = data.deviceId as string;
      if (!userId || !deviceId) continue;
      if (!devicesByUser.has(userId)) devicesByUser.set(userId, new Set());
      devicesByUser.get(userId)!.add(deviceId);
    }

    let totalAccountsWithMultipleDevices = 0;
    let estimatedSharedAccounts = 0;
    for (const deviceSet of devicesByUser.values()) {
      if (deviceSet.size > 1) totalAccountsWithMultipleDevices++;
      if (deviceSet.size >= 3) estimatedSharedAccounts++;
    }

    let totalMediumFlags = 0;
    let totalHighFlags = 0;
    for (const doc of flagsSnap.docs) {
      const severity = doc.data().severity as string;
      if (severity === 'high') totalHighFlags++;
      else totalMediumFlags++;
    }

    const totalRestrictedAccounts = restrictedSnap.size;
    const potentialRevenueLeakMonthly = estimatedSharedAccounts * MIN_STARTER_PRICE_EUR;

    await db.collection('security_dashboard').doc('latest').set({
      totalAccountsWithMultipleDevices,
      totalMediumFlags,
      totalHighFlags,
      totalRestrictedAccounts,
      estimatedSharedAccounts,
      potentialRevenueLeakMonthly,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info('Security dashboard aggregated', {
      totalAccountsWithMultipleDevices,
      totalMediumFlags,
      totalHighFlags,
      totalRestrictedAccounts,
      estimatedSharedAccounts,
      potentialRevenueLeakMonthly,
    });
  }
);
