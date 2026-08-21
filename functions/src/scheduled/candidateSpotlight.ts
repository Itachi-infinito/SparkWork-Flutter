import * as admin from 'firebase-admin';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { logger } from 'firebase-functions/v2';
import { sendPushToUser } from '../utils/sendPush';

/**
 * Spotlight quotidien — 12h30 (Bruxelles), le « talent du jour ».
 *
 * Choisit UN candidat mis en avant (disponible immédiatement, vérifié en
 * priorité, activation la plus récente) et le signale aux recruteurs ayant
 * au moins une offre active. Jamais de nom dans le push (vie privée) :
 * métier + ville suffisent à créer l'envie d'ouvrir l'app.
 *
 * Respecte la préférence `newProfilesForRecruiter`.
 */

export const candidateSpotlight = onSchedule(
  { schedule: 'every day 12:30', region: 'europe-west1', timeZone: 'Europe/Brussels' },
  async () => {
    const db = admin.firestore();
    const nowIso = new Date().toISOString();

    // 1. Talent du jour : dispo maintenant, vérifié d'abord, le plus récent.
    const availableSnap = await db
      .collection('candidate_profiles')
      .where('isAvailableNow', '==', true)
      .get();

    const candidates = availableSnap.docs
      .map((d) => d.data())
      .filter((c) => (c.availableNowUntil as string | undefined ?? '') > nowIso);

    if (candidates.length === 0) {
      logger.info('candidateSpotlight: aucun candidat disponible — pas de push');
      return;
    }

    candidates.sort((a, b) => {
      const aVerified = a.verificationStatus === 'verified' ? 1 : 0;
      const bVerified = b.verificationStatus === 'verified' ? 1 : 0;
      if (aVerified !== bVerified) return bVerified - aVerified;
      return String(b.availableNowUpdatedAt ?? '').localeCompare(String(a.availableNowUpdatedAt ?? ''));
    });
    const pick = candidates[0];

    const title = pick.jobTitle ? String(pick.jobTitle) : 'Un talent';
    const city = pick.location ? ` à ${pick.location}` : '';
    const verified = pick.verificationStatus === 'verified' ? ' · identité vérifiée ✓' : '';
    const pickSectors = new Set<string>((pick.sectors as string[] | undefined) ?? ['horeca']);

    // 2. Destinataires : recruteurs avec au moins une offre active dans le
    // même secteur que le candidat mis en avant (sinon le push n'a aucun
    // intérêt pour eux).
    const offersSnap = await db
      .collection('job_offers')
      .where('isActive', '==', true)
      .get();
    const recruiterIds = new Set<string>();
    for (const doc of offersSnap.docs) {
      const data = doc.data();
      const rid = data.recruiterUserId as string | undefined;
      const sector = (data.sector as string | undefined) ?? 'horeca';
      if (rid && pickSectors.has(sector)) recruiterIds.add(rid);
    }

    let sent = 0;
    for (const userId of recruiterIds) {
      try {
        const prefDoc = await db.collection('notification_preferences').doc(userId).get();
        const allowed = (prefDoc.data()?.newProfilesForRecruiter as boolean | undefined) ?? true;
        if (!allowed) continue;

        await sendPushToUser(
          userId,
          {
            title: '🌟 Talent du jour',
            body: `${title}${city}, disponible immédiatement${verified}. Soyez le premier à swiper.`,
          },
          { route: '/recruiter/swipe' }
        );
        sent++;
      } catch (e) {
        logger.error(`candidateSpotlight failed for ${userId}`, e);
      }
    }

    logger.info(`candidateSpotlight: ${sent} push(es) envoyé(s)`);
  }
);
