import * as admin from 'firebase-admin';
import { logger } from 'firebase-functions/v2';
import { sendPushToUser } from '../utils/sendPush';

type Severity = 'medium' | 'high';
interface DetectedFlag {
  flagType: string;
  severity: Severity;
}

const RESTRICTED_HIGH_FLAGS_THRESHOLD = 3; // en 7 jours
const RESTRICTED_WINDOW_DAYS = 7;
const DISTINCT_DEVICES_30D_THRESHOLD = 4;

/**
 * Analyse les sessions des dernières 24h/30j pour détecter un partage de
 * compte probable, et escalade vers le mode restreint si nécessaire.
 * Appelée juste après la création de chaque nouvelle session (voir
 * createActiveSession.ts) — jamais bloquante pour la connexion elle-même.
 */
export async function checkAnomaliesAfterSession(
  db: admin.firestore.Firestore,
  userId: string,
  deviceId: string,
  deviceOS: string,
  country: string | null
): Promise<void> {
  const since24h = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const sessions24hSnap = await db
    .collection('active_sessions')
    .where('userId', '==', userId)
    .where('loginAt', '>=', since24h)
    .get();

  const deviceIds24h = new Set(sessions24hSnap.docs.map((d) => d.data().deviceId as string));
  const osFamilies24h = new Set(
    sessions24hSnap.docs.map((d) => ((d.data().deviceOS as string) || '').split(' ')[0])
  );
  const connectionCount24h = sessions24hSnap.size;

  const flags: DetectedFlag[] = [];
  if (deviceIds24h.size > 2) {
    flags.push({ flagType: 'multiple_devices_24h', severity: 'medium' });
  }
  if (osFamilies24h.size >= 2) {
    flags.push({ flagType: 'multiple_os_same_day', severity: 'medium' });
  }
  if (connectionCount24h > 3) {
    flags.push({ flagType: 'excessive_connections_24h', severity: 'high' });
  }

  // Pays inhabituel : comparé au pays le plus fréquent des 30 derniers jours.
  if (country) {
    const since30d = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();
    const sessions30dSnap = await db
      .collection('active_sessions')
      .where('userId', '==', userId)
      .where('loginAt', '>=', since30d)
      .get();

    const countryCounts: Record<string, number> = {};
    for (const doc of sessions30dSnap.docs) {
      const c = doc.data().country as string | undefined;
      if (c) countryCounts[c] = (countryCounts[c] ?? 0) + 1;
    }
    const sorted = Object.entries(countryCounts).sort((a, b) => b[1] - a[1]);
    const usualCountry = sorted[0]?.[0];
    // Il faut un historique minimal avant de juger un pays "inhabituel".
    if (usualCountry && country !== usualCountry && sessions30dSnap.size > 3) {
      flags.push({ flagType: 'unusual_country', severity: 'high' });
    }

    // Partage probable : 5+ connexions depuis des appareils distincts en 30j
    // -> trigger upsell équipe par email (voir Sprint 5, trigger 3).
    const distinctDevices30d = new Set(sessions30dSnap.docs.map((d) => d.data().deviceId));
    if (distinctDevices30d.size >= DISTINCT_DEVICES_30D_THRESHOLD + 1) {
      await maybeQueueTeamUpsellEmail(db, userId, distinctDevices30d.size);
    }
  }

  if (flags.length === 0) return;

  for (const flag of flags) {
    const flagRef = db.collection('security_flags').doc();
    await flagRef.set({
      userId,
      flagType: flag.flagType,
      severity: flag.severity,
      detectedAt: admin.firestore.FieldValue.serverTimestamp(),
      resolved: false,
    });

    if (flag.severity === 'medium') {
      await sendPushToUser(
        userId,
        {
          title: 'Activité inhabituelle détectée',
          body:
            'Nous avons remarqué une connexion inhabituelle sur votre compte. ' +
            'Votre sécurité est notre priorité — pouvez-vous confirmer que c\'est bien vous ?',
        },
        { type: 'security_flag', flagId: flagRef.id, severity: 'medium' }
      );
    } else {
      await sendPushToUser(
        userId,
        {
          title: 'Activité inhabituelle détectée',
          body:
            'Nous avons remarqué une connexion inhabituelle sur votre compte. ' +
            'Votre sécurité est notre priorité — pouvez-vous confirmer que c\'est bien vous ?',
        },
        { type: 'security_flag', flagId: flagRef.id, severity: 'high' }
      );
      await checkRestrictedModeEscalation(db, userId);
    }
  }
}

async function checkRestrictedModeEscalation(
  db: admin.firestore.Firestore,
  userId: string
): Promise<void> {
  const sinceWindow = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - RESTRICTED_WINDOW_DAYS * 24 * 60 * 60 * 1000)
  );
  const recentHighFlags = await db
    .collection('security_flags')
    .where('userId', '==', userId)
    .where('severity', '==', 'high')
    .where('detectedAt', '>=', sinceWindow)
    .get();

  if (recentHighFlags.size >= RESTRICTED_HIGH_FLAGS_THRESHOLD) {
    await enableRestrictedMode(db, userId);
  }
}

async function enableRestrictedMode(
  db: admin.firestore.Firestore,
  userId: string
): Promise<void> {
  const userRef = db.collection('users').doc(userId);
  const userDoc = await userRef.get();
  if (userDoc.data()?.isRestricted === true) return; // déjà restreint

  const previousCount = (userDoc.data()?.restrictedModeCount as number) ?? 0;
  const newCount = previousCount + 1;

  await userRef.set(
    {
      isRestricted: true,
      restrictedAt: admin.firestore.FieldValue.serverTimestamp(),
      restrictedModeCount: newCount,
    },
    { merge: true }
  );

  await sendPushToUser(userId, {
    title: 'Compte temporairement restreint',
    body:
      'Pour protéger votre compte, nous avons temporairement limité certaines ' +
      'fonctionnalités. Une vérification rapide suffit pour tout restaurer.',
  });

  if (newCount >= 2) {
    await maybeQueueTeamUpsellEmail(db, userId, 0, true);
  }

  logger.info(`Restricted mode enabled for ${userId} (occurrence #${newCount})`);
}

/**
 * Email d'upsell vers la Gestion d'équipe Pro — limité à 1x/mois par
 * utilisateur. L'envoi réel n'est PAS encore branché (aucun fournisseur
 * d'emailing configuré, ex: SendGrid/Mailgun) — l'intention est journalisée
 * et la dernière date de queue est tracée pour respecter la limite,
 * de sorte que le branchement réel n'aura qu'à lire `pendingTeamUpsellEmail`.
 *
 * TODO: brancher un fournisseur d'emailing et envoyer réellement le message
 * "Plusieurs personnes utilisent votre compte SparkWork ?" depuis
 * support@sparkwork.be.
 */
async function maybeQueueTeamUpsellEmail(
  db: admin.firestore.Firestore,
  userId: string,
  distinctDeviceCount: number,
  forcedByRestriction = false
): Promise<void> {
  const userRef = db.collection('users').doc(userId);
  const userDoc = await userRef.get();
  const lastSent = userDoc.data()?.lastTeamUpsellEmailAt as admin.firestore.Timestamp | undefined;
  if (lastSent && Date.now() - lastSent.toMillis() < 30 * 24 * 60 * 60 * 1000) {
    return; // déjà envoyé ce mois-ci
  }

  await userRef.set(
    {
      lastTeamUpsellEmailAt: admin.firestore.FieldValue.serverTimestamp(),
      pendingTeamUpsellEmail: true,
    },
    { merge: true }
  );

  logger.info(
    `Team upsell email queued for ${userId} ` +
      (forcedByRestriction
        ? '(triggered by repeated restricted mode)'
        : `(${distinctDeviceCount} distinct devices in 30 days)`)
  );
}
