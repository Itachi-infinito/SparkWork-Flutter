import * as admin from 'firebase-admin';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions/v2';
import { sendPushToUser } from '../utils/sendPush';

/**
 * Radar de talents — SparkInvite : notifie un candidat passif (non
 * "disponible maintenant") qu'un recruteur s'intéresse à son profil pour
 * une offre précise, sans jamais lui dire qu'il a été repéré via le radar.
 */
export const onSparkInviteCreated = onDocumentCreated(
  { document: 'sparkInvites/{inviteId}', region: 'europe-west1' },
  async (event) => {
    const invite = event.data?.data();
    if (!invite) return;

    const db = admin.firestore();
    const offerDoc = await db.collection('job_offers').doc(invite.offerId).get();
    if (!offerDoc.exists) return;
    const offer = offerDoc.data()!;

    await sendPushToUser(
      invite.receiverId,
      {
        title: 'Un recruteur est intéressé par votre profil',
        body: `Un poste de ${offer.title} à ${offer.location} pourrait vous intéresser. `
          + 'Voulez-vous en savoir plus ?',
      },
      { type: 'spark_invite', offerId: invite.offerId, inviteId: event.params.inviteId }
    );

    logger.info('SparkInvite notification sent', { inviteId: event.params.inviteId });
  }
);
