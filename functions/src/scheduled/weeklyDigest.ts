import * as admin from 'firebase-admin';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { logger } from 'firebase-functions/v2';
import { sendPushToUser } from '../utils/sendPush';

/**
 * Digest hebdomadaire recruteur — lundi 09h00 (Bruxelles).
 *
 * Boucle de rétention : ramène le recruteur dans l'app en début de semaine
 * avec SES chiffres (likes reçus, nouveaux matches) + le vivier du moment
 * (candidats disponibles immédiatement). Pas d'email tant que le domaine
 * n'est pas vérifié — le push suffit et arrive là où est l'utilisateur.
 *
 * Respecte la préférence `newProfilesForRecruiter` (opt-out par défaut à
 * true si le document de préférences n'existe pas).
 */

function tsToMillis(v: unknown): number {
  if (v instanceof admin.firestore.Timestamp) return v.toMillis();
  if (typeof v === 'string') {
    const t = new Date(v).getTime();
    return isNaN(t) ? 0 : t;
  }
  return 0;
}

async function digestAllowed(
  db: admin.firestore.Firestore,
  userId: string
): Promise<boolean> {
  const doc = await db.collection('notification_preferences').doc(userId).get();
  return (doc.data()?.newProfilesForRecruiter as boolean | undefined) ?? true;
}

export const weeklyDigest = onSchedule(
  { schedule: 'every monday 09:00', region: 'europe-west1', timeZone: 'Europe/Brussels' },
  async () => {
    const db = admin.firestore();
    const weekAgo = Date.now() - 7 * 24 * 3600 * 1000;
    const nowIso = new Date().toISOString();

    // Vivier global des disponibles maintenant, groupé par secteur — pour
    // ne montrer à chaque recruteur que ce qui le concerne.
    const availableSnap = await db
      .collection('candidate_profiles')
      .where('isAvailableNow', '==', true)
      .get();
    const availableNowBySector: Record<string, number> = {};
    for (const doc of availableSnap.docs) {
      const data = doc.data();
      const until = data.availableNowUntil as string | undefined;
      if (until == null || until <= nowIso) continue;
      const sectors = (data.sectors as string[] | undefined) ?? ['horeca'];
      for (const sector of sectors) {
        availableNowBySector[sector] = (availableNowBySector[sector] ?? 0) + 1;
      }
    }

    const recruitersSnap = await db.collection('recruiter_profiles').get();
    let sent = 0;

    for (const recruiterDoc of recruitersSnap.docs) {
      const userId = recruiterDoc.data().userId as string | undefined;
      if (!userId) continue;

      try {
        if (!(await digestAllowed(db, userId))) continue;

        const [offersSnap, matchesSnap] = await Promise.all([
          db.collection('job_offers')
            .where('recruiterUserId', '==', userId)
            .get(),
          db.collection('matches')
            .where('recruiterUserId', '==', userId)
            .get(),
        ]);

        // candidate_job_likes n'a pas de champ recruiterUserId (les règles
        // Firestore vérifient via une jointure job_offers) — on filtre donc
        // par jobOfferId parmi les offres du recruteur, comme côté client.
        const offerIds = offersSnap.docs.map((d) => d.id);
        const recruiterSectors = new Set<string>(
          offersSnap.docs.map((d) => (d.data().sector as string | undefined) ?? 'horeca')
        );
        let likesThisWeek = 0;
        const chunkSize = 10; // limite Firestore whereIn
        for (let i = 0; i < offerIds.length; i += chunkSize) {
          const chunk = offerIds.slice(i, i + chunkSize);
          if (chunk.length === 0) continue;
          const likesSnap = await db.collection('candidate_job_likes')
            .where('jobOfferId', 'in', chunk)
            .get();
          likesThisWeek += likesSnap.docs.filter(
            (d) => tsToMillis(d.data().createdAt) >= weekAgo
          ).length;
        }

        const matchesThisWeek = matchesSnap.docs.filter(
          (d) => tsToMillis(d.data().createdAt) >= weekAgo
        ).length;

        const availableNowCount = [...recruiterSectors].reduce(
          (sum, sector) => sum + (availableNowBySector[sector] ?? 0), 0
        );

        // Rien à raconter → pas de push. Un digest vide désabonne mentalement.
        if (likesThisWeek === 0 && matchesThisWeek === 0 && availableNowCount === 0) {
          continue;
        }

        const parts: string[] = [];
        if (likesThisWeek > 0) {
          parts.push(`${likesThisWeek} candidat${likesThisWeek > 1 ? 's ont' : ' a'} liké vos offres`);
        }
        if (matchesThisWeek > 0) {
          parts.push(`${matchesThisWeek} nouveau${matchesThisWeek > 1 ? 'x' : ''} match${matchesThisWeek > 1 ? 's' : ''}`);
        }
        if (availableNowCount > 0) {
          parts.push(`${availableNowCount} talent${availableNowCount > 1 ? 's' : ''} disponible${availableNowCount > 1 ? 's' : ''} immédiatement`);
        }

        await sendPushToUser(
          userId,
          {
            title: '📊 Votre semaine SparkWork',
            body: `${parts.join(' · ')}. Ne les laissez pas filer !`,
          },
          { route: '/recruiter/swipe' }
        );
        sent++;
      } catch (e) {
        logger.error(`weeklyDigest failed for ${userId}`, e);
      }
    }

    logger.info(`weeklyDigest: ${sent} push(es) envoyé(s)`);
  }
);
