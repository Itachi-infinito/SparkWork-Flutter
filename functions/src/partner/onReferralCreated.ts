import * as admin from 'firebase-admin';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions/v2';

/**
 * Incrémente partners/{partnerId}.totalReferrals via l'Admin SDK (qui
 * contourne les Security Rules). Le client n'a jamais le droit d'écrire
 * dans `partners` (allow write: if false) — c'était auparavant tenté
 * côté client dans PartnerService.registerReferral() et échouait
 * silencieusement. Ce trigger est la seule source de vérité du compteur.
 */
export const onReferralCreated = onDocumentCreated(
  { document: 'referrals/{refId}', region: 'europe-west1' },
  async (event) => {
    const referral = event.data?.data();
    if (!referral?.partnerId) return;

    try {
      await admin
        .firestore()
        .collection('partners')
        .doc(referral.partnerId)
        .update({ totalReferrals: admin.firestore.FieldValue.increment(1) });
    } catch (e) {
      logger.error(`Failed to increment totalReferrals for partner ${referral.partnerId}`, e);
    }
  }
);
