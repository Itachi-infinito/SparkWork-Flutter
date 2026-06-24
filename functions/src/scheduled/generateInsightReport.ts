import * as admin from 'firebase-admin';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { logger } from 'firebase-functions/v2';

const HORECA_SECTOR = 'Horeca';
const DEFAULT_REGION = 'Belgique';

/**
 * Génère le rapport insight marché le 1er de chaque mois à 4h UTC
 * pour le mois précédent. Agrège les données de l'ensemble de la
 * plateforme (salaires, compétences recherchées, temps moyen de match)
 * pour donner aux recruteurs Pro une vue sectorielle.
 */
export const generateInsightReport = onSchedule(
  { schedule: '0 4 1 * *', region: 'europe-west1', timeZone: 'UTC' },
  async () => {
    const db = admin.firestore();
    const now = new Date();

    // On génère le rapport du mois précédent
    const targetDate = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const month = targetDate.getMonth() + 1; // 1-12
    const year = targetDate.getFullYear();
    const monthStart = new Date(year, month - 1, 1).toISOString();
    const monthEnd = new Date(year, month, 1).toISOString();

    const reportId = `${year}-${String(month).padStart(2, '0')}`;

    // Évite les doublons si la fonction est relancée
    const existing = await db.collection('insight_reports').doc(reportId).get();
    if (existing.exists) {
      logger.info(`generateInsightReport: report ${reportId} already exists`);
      return;
    }

    // ─── Profils candidats actifs ──────────────────────────────────────────
    const candidateSnap = await db
      .collection('candidate_profiles')
      .where('updatedAt', '>=', monthStart)
      .where('updatedAt', '<', monthEnd)
      .get();

    const totalActiveProfiles = candidateSnap.size;

    // ─── Salaire moyen par rôle ───────────────────────────────────────────
    const salaryByRole: Record<string, { total: number; count: number }> = {};

    for (const doc of candidateSnap.docs) {
      const data = doc.data();
      const role = (data.jobTitle as string | undefined)?.trim();
      const salary = (data.expectedSalary as number | undefined);
      if (role && salary && salary > 0) {
        if (!salaryByRole[role]) salaryByRole[role] = { total: 0, count: 0 };
        salaryByRole[role].total += salary;
        salaryByRole[role].count += 1;
      }
    }

    const averageSalaryByRole: Record<string, number> = {};
    for (const [role, { total, count }] of Object.entries(salaryByRole)) {
      if (count >= 3) { // minimum 3 candidats pour la pertinence statistique
        averageSalaryByRole[role] = Math.round(total / count);
      }
    }

    // ─── Compétences les plus recherchées (dans les offres du mois) ───────
    const offersSnap = await db
      .collection('job_offers')
      .where('createdAt', '>=', monthStart)
      .where('createdAt', '<', monthEnd)
      .get();

    const skillCount: Record<string, number> = {};
    for (const doc of offersSnap.docs) {
      const skills = String(doc.data().requiredSkills ?? '')
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .filter(Boolean);
      for (const skill of skills) {
        skillCount[skill] = (skillCount[skill] ?? 0) + 1;
      }
    }
    const mostSearchedSkills = Object.entries(skillCount)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 10)
      .map(([skill]) => skill);

    // ─── Temps moyen de match (de la création du match à la date du match) ─
    const matchesSnap = await db
      .collection('matches')
      .where('createdAt', '>=', monthStart)
      .where('createdAt', '<', monthEnd)
      .get();

    let totalMatchHours = 0;
    let matchCount = 0;
    for (const doc of matchesSnap.docs) {
      const data = doc.data();
      const offerCreatedAt = data.offerCreatedAt as string | undefined;
      const matchCreatedAt = data.createdAt as string | undefined;
      if (offerCreatedAt && matchCreatedAt) {
        const diffMs = new Date(matchCreatedAt).getTime() - new Date(offerCreatedAt).getTime();
        if (diffMs > 0) {
          totalMatchHours += diffMs / (1000 * 60 * 60);
          matchCount += 1;
        }
      }
    }
    const averageMatchTimeHours = matchCount > 0 ? Math.round(totalMatchHours / matchCount) : 0;

    // ─── Écriture du rapport ──────────────────────────────────────────────
    const report = {
      reportId,
      month,
      year,
      sector: HORECA_SECTOR,
      region: DEFAULT_REGION,
      averageSalaryByRole,
      mostSearchedSkills,
      averageMatchTimeHours,
      totalActiveProfiles,
      generatedAt: now.toISOString(),
    };

    await db.collection('insight_reports').doc(reportId).set(report);
    logger.info(`generateInsightReport: generated ${reportId} — ${totalActiveProfiles} profiles, ${offersSnap.size} offers, ${matchesSnap.size} matches`);
  }
);
