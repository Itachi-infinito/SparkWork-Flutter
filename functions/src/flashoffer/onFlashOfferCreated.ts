import * as admin from 'firebase-admin';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions/v2';
import { sendPushToUser } from '../utils/sendPush';

const FLASH_RADIUS_KM = 50;

function distanceKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/**
 * Notifie les candidats à moins de 50 km quand une offre Flash est publiée.
 * Sans cette notification, les candidats ne voient les offres Flash que par
 * hasard en ouvrant l'app — le modèle "urgence + proximité" perd son sens.
 *
 * On limite à 200 profils pour la latence (les offres Flash durent 2h à 72h,
 * l'envoi doit être quasi-immédiat). Les candidats plus loin reçoivent l'offre
 * via le swipe normal sans notification spéciale.
 */
export const onFlashOfferCreated = onDocumentCreated(
  { document: 'job_offers/{offerId}', region: 'europe-west1' },
  async (event) => {
    const offer = event.data?.data();
    if (!offer) return;
    if (!offer.isFlash || !offer.isActive) return;

    const offerLat = offer.latitude as number | undefined;
    const offerLon = offer.longitude as number | undefined;
    const offerId = event.params.offerId;

    const db = admin.firestore();
    const candidatesSnap = await db
      .collection('candidate_profiles')
      .limit(200)
      .get();

    const sends: Promise<void>[] = [];

    for (const doc of candidatesSnap.docs) {
      const profile = doc.data();
      const userId = profile.userId as string | undefined;
      if (!userId) continue;

      const candLat = profile.latitude as number | undefined;
      const candLon = profile.longitude as number | undefined;

      // Si l'une des deux coordonnées manque → notification quand même
      // (pas de coords = on envoie pour ne pas rater une dispo)
      const shouldNotify =
        !offerLat || !offerLon || !candLat || !candLon ||
        distanceKm(offerLat, offerLon, candLat, candLon) <= FLASH_RADIUS_KM;

      if (!shouldNotify) continue;

      sends.push(
        sendPushToUser(
          userId,
          {
            title: '⚡ Mission Flash à pourvoir !',
            body: `${offer.title ?? 'Nouvelle mission'} — ${offer.location ?? 'Belgique'} · ${offer.flashDurationHours ?? '?'}h`,
          },
          { type: 'flash_offer', offerId }
        ).catch((e) => {
          logger.warn(`onFlashOfferCreated: failed to notify ${userId}`, e);
        })
      );
    }

    await Promise.allSettled(sends);
    logger.info(`onFlashOfferCreated: notified ${sends.length} candidate(s) for offer ${offerId}`);
  }
);
