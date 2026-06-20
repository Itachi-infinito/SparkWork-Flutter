import * as admin from 'firebase-admin';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions/v2';

/**
 * Recalcule average_ratings/{toUserId} via l'Admin SDK. Le client ne peut
 * pas le faire lui-même : les Security Rules n'autorisent que
 * `request.auth.uid == userId` à écrire son propre average_ratings, alors
 * que c'est l'AUTRE participant (celui qui note) qui déclenche le calcul.
 * Tenter cette écriture côté client (ancien code dans RatingService)
 * provoquait un permission-denied après la création réussie de la note,
 * laissant croire à l'utilisateur que son évaluation n'avait pas été envoyée.
 */
export const onRatingCreated = onDocumentCreated(
  { document: 'ratings/{ratingId}', region: 'europe-west1' },
  async (event) => {
    const rating = event.data?.data();
    if (!rating?.toUserId) return;

    try {
      const db = admin.firestore();
      const snap = await db
        .collection('ratings')
        .where('toUserId', '==', rating.toUserId)
        .where('isHidden', '==', false)
        .get();

      if (snap.empty) return;

      const scores = snap.docs.map((d) => d.data().score as number);
      const avg = scores.reduce((a, b) => a + b, 0) / scores.length;

      await db.collection('average_ratings').doc(rating.toUserId).set({
        userId: rating.toUserId,
        averageScore: Math.round(avg * 10) / 10,
        totalReviews: scores.length,
      });
    } catch (e) {
      logger.error(`Failed to recalculate average_ratings for ${rating.toUserId}`, e);
    }
  }
);
