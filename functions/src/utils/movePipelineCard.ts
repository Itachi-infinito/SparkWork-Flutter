import * as admin from 'firebase-admin';

/**
 * Déplace automatiquement la carte pipeline d'un match vers une colonne,
 * en réaction à un vrai événement (entretien accepté, embauche confirmée)
 * plutôt que d'attendre un glisser-déposer manuel — sinon le pipeline
 * affiche un état périmé qui ne reflète jamais ce qui s'est réellement
 * passé ailleurs dans l'app.
 */
export async function movePipelineCardForMatch(
  db: admin.firestore.Firestore,
  recruiterUserId: string,
  matchId: string,
  column: string
): Promise<void> {
  try {
    const cardsRef = db.collection('recruiter_pipeline').doc(recruiterUserId).collection('cards');
    const snap = await cardsRef.where('matchId', '==', matchId).limit(1).get();
    if (snap.empty) return;
    await snap.docs[0].ref.update({ column, movedAt: new Date().toISOString() });
  } catch {
    // Le pipeline est un confort de visualisation — une erreur ici ne
    // doit jamais faire échouer le flux métier (confirmation d'embauche,
    // acceptation d'entretien) qui l'a déclenché.
  }
}
