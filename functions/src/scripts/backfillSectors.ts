/**
 * Migration one-shot : tague sector='horeca' (job_offers) et
 * sectors=['horeca'] (candidate_profiles, recruiter_profiles) sur tous les
 * documents créés avant l'introduction des secteurs — ils étaient tous
 * implicitement Horeca.
 *
 * Usage (depuis functions/) :
 *   npm run build
 *   GOOGLE_APPLICATION_CREDENTIALS=/chemin/vers/serviceAccountKey.json node lib/scripts/backfillSectors.js
 *
 * Le compte de service doit avoir accès à Firestore sur le projet
 * (rôle "Cloud Datastore User" ou "Editor" suffit). Le SDK Admin ignore les
 * règles de sécurité Firestore, donc ce script voit et modifie tous les
 * documents quel que soit leur propriétaire.
 */
import * as admin from 'firebase-admin';

admin.initializeApp();
const db = admin.firestore();

async function backfillCollection(
  collectionName: string,
  field: string,
  value: unknown,
) {
  const snap = await db.collection(collectionName).get();
  const toUpdate = snap.docs.filter((doc) => !(field in doc.data()));

  console.log(
    `${collectionName}: ${toUpdate.length}/${snap.size} documents sans '${field}'`,
  );

  const chunkSize = 400; // limite Firestore : 500 opérations par batch
  for (let i = 0; i < toUpdate.length; i += chunkSize) {
    const batch = db.batch();
    for (const doc of toUpdate.slice(i, i + chunkSize)) {
      batch.update(doc.ref, { [field]: value });
    }
    await batch.commit();
    console.log(`  -> ${Math.min(i + chunkSize, toUpdate.length)}/${toUpdate.length} migrés`);
  }
}

async function main() {
  await backfillCollection('job_offers', 'sector', 'horeca');
  await backfillCollection('candidate_profiles', 'sectors', ['horeca']);
  await backfillCollection('recruiter_profiles', 'sectors', ['horeca']);
  console.log('Migration terminée.');
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Échec de la migration :', err);
    process.exit(1);
  });
