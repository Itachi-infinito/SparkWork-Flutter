import * as admin from 'firebase-admin';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions/v2';
import { buildMatchReport, isRecruiterPro } from './buildMatchReport';

/**
 * Génère automatiquement une fiche de candidature synthétique quand un
 * match se crée avec une offre d'un recruteur Pro. Mise en cache dans
 * match_reports/{matchId} — lue par l'app depuis la conversation et la
 * liste des matchs (jamais recalculée côté client).
 *
 * Ne couvre que l'éligibilité Pro AU MOMENT du match — si le recruteur
 * passe Pro après coup, voir regenerateMatchReport (callable) pour
 * générer rétroactivement.
 */
export const generateMatchReport = onDocumentCreated(
  { document: 'matches/{matchId}', region: 'europe-west1' },
  async (event) => {
    const match = event.data?.data();
    const matchId = event.params.matchId;
    if (!match) return;

    const db = admin.firestore();

    try {
      if (!(await isRecruiterPro(db, match.recruiterUserId))) return;
      const ok = await buildMatchReport(db, matchId, match);
      if (ok) logger.info(`Match report generated for ${matchId}`);
    } catch (e) {
      logger.error(`generateMatchReport failed for ${matchId}`, e);
    }
  }
);
