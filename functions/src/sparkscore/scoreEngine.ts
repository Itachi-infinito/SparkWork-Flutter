export const SPARK_SCORE_WEIGHTS = {
  skills: 0.30,
  location: 0.20,
  availability: 0.15,
  salary: 0.15,
  ratings: 0.10,
  stability: 0.10,
};

export interface ScoreFactor {
  value: number; // 0-100
  weight: number;
  explanation: string;
}

export interface SparkScoreFactors {
  skills: ScoreFactor;
  location: ScoreFactor;
  availability: ScoreFactor;
  salary: ScoreFactor;
  ratings: ScoreFactor;
  stability: ScoreFactor;
}

export function haversineKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) * Math.cos((lat2 * Math.PI) / 180) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/**
 * Calcul pur des 6 facteurs pondérés du SparkScore — pas d'accès DB ici,
 * pour rester réutilisable depuis n'importe quel appelant (Callable
 * calculateSparkScore, génération de rapport de candidature, etc.) sans
 * dupliquer la logique de pondération.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function computeSparkScoreFactors(
  offer: Record<string, any>,
  candidate: Record<string, any>,
  rating: Record<string, any> | undefined
): { globalScore: number; factors: SparkScoreFactors } {
  // 1. Compétences (30%)
  const requiredSkills: string[] = offer.requiredSkills
    ? String(offer.requiredSkills).split(',').map((s) => s.trim().toLowerCase()).filter(Boolean)
    : [];
  // candidate.skills est stocké comme une chaîne "skill1, skill2, ..."
  // (cf. CandidateProfile.toMap() côté Flutter), jamais comme un tableau.
  const candidateSkills = new Set(
    String(candidate.skills ?? '').split(',').map((s) => s.trim().toLowerCase()).filter(Boolean)
  );
  const skillsValue = requiredSkills.length === 0
    ? 100
    : Math.round((requiredSkills.filter((s) => candidateSkills.has(s)).length / requiredSkills.length) * 100);
  const skillsFactor: ScoreFactor = {
    value: skillsValue,
    weight: SPARK_SCORE_WEIGHTS.skills,
    explanation: requiredSkills.length === 0
      ? 'Aucune compétence spécifique requise par l\'offre.'
      : skillsValue >= 80
        ? 'Correspondance excellente sur les compétences requises.'
        : skillsValue >= 50
          ? 'Correspondance partielle sur les compétences requises.'
          : 'Peu de compétences requises correspondent.',
  };

  // 2. Localisation / rayon (20%) — 0km = 100, 50km+ = 0
  let locationValue = 70; // neutre si coordonnées manquantes
  let locationExplanation = 'Localisation non renseignée pour l\'un des deux profils.';
  if (offer.latitude && offer.longitude && candidate.latitude && candidate.longitude) {
    const distanceKm = haversineKm(
      offer.latitude, offer.longitude, candidate.latitude, candidate.longitude
    );
    locationValue = Math.max(0, Math.round(100 - (distanceKm / 50) * 100));
    locationExplanation = distanceKm <= 10
      ? `Très proche (${distanceKm.toFixed(0)} km).`
      : distanceKm <= 30
        ? `Distance raisonnable (${distanceKm.toFixed(0)} km).`
        : `Distance importante (${distanceKm.toFixed(0)} km).`;
  }
  const locationFactor: ScoreFactor = { value: locationValue, weight: SPARK_SCORE_WEIGHTS.location, explanation: locationExplanation };

  // 3. Disponibilité (15%)
  // TODO: affiner avec une vraie date de prise de poste souhaitée côté
  // offre — non disponible dans le modèle actuel, on se base sur
  // isAvailableNow en attendant.
  const isAvailableNow = candidate.isAvailableNow === true &&
    candidate.availableNowUntil &&
    new Date(candidate.availableNowUntil).getTime() > Date.now();
  const availabilityFactor: ScoreFactor = {
    value: isAvailableNow ? 100 : 60,
    weight: SPARK_SCORE_WEIGHTS.availability,
    explanation: isAvailableNow
      ? 'Candidat disponible immédiatement.'
      : 'Disponibilité non confirmée comme immédiate.',
  };

  // 4. Salaire (15%)
  let salaryValue = 70;
  let salaryExplanation = 'Prétentions salariales non renseignées.';
  const candMin = candidate.desiredSalaryMin ?? 0;
  const candMax = candidate.desiredSalaryMax ?? 0;
  const offerMin = offer.salaryMin ?? 0;
  const offerMax = offer.salaryMax ?? 0;
  if ((candMin || candMax) && (offerMin || offerMax)) {
    const candMid = (candMin + candMax) / 2;
    const offerMid = (offerMin + offerMax) / 2;
    const diff = Math.abs(candMid - offerMid);
    salaryValue = diff <= 200 ? 100 : diff <= 500 ? 75 : diff <= 1000 ? 50 : 20;
    salaryExplanation = diff <= 200
      ? 'Prétentions salariales parfaitement alignées.'
      : diff <= 500
        ? 'Prétentions salariales proches de l\'offre.'
        : 'Écart notable entre prétentions et offre.';
  }
  const salaryFactor: ScoreFactor = { value: salaryValue, weight: SPARK_SCORE_WEIGHTS.salary, explanation: salaryExplanation };

  // 5. Notes reçues (10%) — neutre (70) si pas encore noté
  const avgScore = (rating?.averageScore as number | undefined) ?? 3.5;
  const ratingsValue = Math.round((avgScore / 5) * 100);
  const ratingsFactor: ScoreFactor = {
    value: ratingsValue,
    weight: SPARK_SCORE_WEIGHTS.ratings,
    explanation: rating
      ? `Note moyenne de ${avgScore.toFixed(1)}/5 sur ${rating.totalReviews ?? 0} avis.`
      : 'Pas encore d\'avis reçus.',
  };

  // 6. Stabilité professionnelle (10%)
  // TODO: nécessite un historique d'expériences structuré (durées) qui
  // n'existe pas encore dans candidate_profiles — valeur neutre pour
  // l'instant, à affiner quand ce champ sera modélisé.
  const stabilityFactor: ScoreFactor = {
    value: 70,
    weight: SPARK_SCORE_WEIGHTS.stability,
    explanation: 'Donnée non disponible — estimation neutre.',
  };

  const factors: SparkScoreFactors = {
    skills: skillsFactor,
    location: locationFactor,
    availability: availabilityFactor,
    salary: salaryFactor,
    ratings: ratingsFactor,
    stability: stabilityFactor,
  };

  const globalScore = Math.round(
    Object.values(factors).reduce((sum, f) => sum + f.value * f.weight, 0)
  );

  return { globalScore, factors };
}
