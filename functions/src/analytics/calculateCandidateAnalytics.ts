import * as admin from 'firebase-admin';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { logger } from 'firebase-functions/v2';

const HIGHLY_DEMANDED_THRESHOLD = 5;

function parseYM(ym: string): Date {
  const [y, m] = ym.split('-').map(Number);
  return new Date(y, (m || 1) - 1, 1);
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function computeStabilityMonths(workHistory: any): number | null {
  if (!Array.isArray(workHistory) || workHistory.length < 2) return null;
  const now = new Date();
  const tenures = workHistory
    .filter((e) => e?.startDate)
    .map((e) => {
      const start = parseYM(String(e.startDate));
      const end = e.isCurrent || !e.endDate ? now : parseYM(String(e.endDate));
      return Math.max(0, (end.getFullYear() - start.getFullYear()) * 12 + (end.getMonth() - start.getMonth()));
    });
  if (tenures.length < 2) return null;
  return Math.round(tenures.reduce((a, b) => a + b, 0) / tenures.length);
}

/**
 * Analyse de profil candidat approfondie (Pro) — calculée quotidiennement,
 * jamais en temps réel côté client. Les données sont anonymisées au sens où
 * le candidat lui-même n'y a jamais accès (cf. Security Rules
 * candidate_analytics : lecture recruteurs uniquement).
 */
export const calculateCandidateAnalytics = onSchedule(
  { schedule: 'every 24 hours', region: 'europe-west1', timeZone: 'Europe/Brussels' },
  async () => {
    const db = admin.firestore();
    const candidatesSnap = await db.collection('candidate_profiles').get();

    const now = Date.now();
    const startOfMonth = admin.firestore.Timestamp.fromDate(
      new Date(now - 30 * 24 * 60 * 60 * 1000)
    );
    const startOfWeek = admin.firestore.Timestamp.fromDate(
      new Date(now - 7 * 24 * 60 * 60 * 1000)
    );

    let processed = 0;
    for (const candidateDoc of candidatesSnap.docs) {
      const candidateData = candidateDoc.data();
      const candidateId = candidateData.userId as string;
      if (!candidateId) continue;

      try {
        const analytics = await computeForCandidate(db, candidateId, candidateData, startOfMonth, startOfWeek);
        await db.collection('candidate_analytics').doc(candidateId).set({
          ...analytics,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        processed++;
      } catch (e) {
        logger.error(`calculateCandidateAnalytics failed for ${candidateId}`, e);
      }
    }

    logger.info(`calculateCandidateAnalytics processed ${processed} candidates`);
  }
);

// eslint-disable-next-line @typescript-eslint/no-explicit-any
async function computeForCandidate(
  db: admin.firestore.Firestore,
  candidateId: string,
  candidateData: Record<string, any>,
  startOfMonth: admin.firestore.Timestamp,
  startOfWeek: admin.firestore.Timestamp
) {
  // Taux de réponse + délai moyen sur les 30 derniers matchs.
  const matchesSnap = await db
    .collection('matches')
    .where('candidateUserId', '==', candidateId)
    .orderBy('createdAt', 'desc')
    .limit(30)
    .get();

  let consideredMatches = 0;
  let respondedMatches = 0;
  const responseTimesHours: number[] = [];

  for (const matchDoc of matchesSnap.docs) {
    const messagesSnap = await db
      .collection('messages')
      .where('matchId', '==', matchDoc.id)
      .orderBy('sentAt', 'asc')
      .get();

    const messages = messagesSnap.docs.map((d) => d.data());
    const firstRecruiterMsg = messages.find((m) => m.senderUserId !== candidateId);
    if (!firstRecruiterMsg) continue; // le recruteur n'a jamais écrit — hors calcul

    consideredMatches++;
    const recruiterTime = new Date(firstRecruiterMsg.sentAt).getTime();
    const firstCandidateReply = messages.find(
      (m) => m.senderUserId === candidateId && new Date(m.sentAt).getTime() >= recruiterTime
    );

    if (firstCandidateReply) {
      respondedMatches++;
      const replyTime = new Date(firstCandidateReply.sentAt).getTime();
      responseTimesHours.push((replyTime - recruiterTime) / (1000 * 60 * 60));
    }
  }

  const responseRate = consideredMatches > 0 ? respondedMatches / consideredMatches : 0;
  const avgResponseTimeHours = responseTimesHours.length > 0
    ? responseTimesHours.reduce((a, b) => a + b, 0) / responseTimesHours.length
    : null;

  // Popularité — recruteurs distincts ayant liké ce candidat.
  const [monthLikesSnap, weekLikesSnap] = await Promise.all([
    db.collection('recruiter_candidate_likes')
      .where('candidateUserId', '==', candidateId)
      .where('createdAt', '>=', startOfMonth)
      .get(),
    db.collection('recruiter_candidate_likes')
      .where('candidateUserId', '==', candidateId)
      .where('createdAt', '>=', startOfWeek)
      .get(),
  ]);

  const recruitersThisMonth = new Set(monthLikesSnap.docs.map((d) => d.data().recruiterUserId)).size;
  const recruitersThisWeek = new Set(weekLikesSnap.docs.map((d) => d.data().recruiterUserId)).size;

  return {
    candidateId,
    responseRate: Math.round(responseRate * 100),
    avgResponseTimeHours: avgResponseTimeHours !== null ? Math.round(avgResponseTimeHours * 10) / 10 : null,
    recruitersThisMonth,
    recruitersThisWeek,
    isHighlyDemanded: recruitersThisWeek > HIGHLY_DEMANDED_THRESHOLD,
    stabilityMonths: computeStabilityMonths(candidateData.workHistory),
  };
}
