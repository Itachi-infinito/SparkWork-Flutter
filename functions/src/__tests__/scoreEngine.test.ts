import { computeSparkScoreFactors, haversineKm } from '../sparkscore/scoreEngine';

describe('haversineKm', () => {
  test('distance nulle entre deux points identiques', () => {
    expect(haversineKm(50.8503, 4.3517, 50.8503, 4.3517)).toBe(0);
  });

  test('distance Bruxelles → Anvers ≈ 42km', () => {
    const d = haversineKm(50.8503, 4.3517, 51.2194, 4.4025);
    expect(d).toBeGreaterThan(38);
    expect(d).toBeLessThan(46);
  });
});

describe('computeSparkScoreFactors', () => {
  test('score élevé quand tout correspond bien', () => {
    const offer = {
      requiredSkills: 'Service en salle, Encaissement',
      latitude: 50.8503,
      longitude: 4.3517,
      salaryMin: 1900,
      salaryMax: 2100,
    };
    const candidate = {
      skills: 'Service en salle, Encaissement, Plonge',
      latitude: 50.8503,
      longitude: 4.3517,
      isAvailableNow: true,
      availableNowUntil: new Date(Date.now() + 86400000).toISOString(),
      desiredSalaryMin: 1900,
      desiredSalaryMax: 2100,
    };
    const { globalScore, factors } = computeSparkScoreFactors(offer, candidate, { averageScore: 5, totalReviews: 10 });

    expect(globalScore).toBeGreaterThanOrEqual(90);
    expect(factors.skills.value).toBe(100);
    expect(factors.location.value).toBe(100);
    expect(factors.availability.value).toBe(100);
  });

  test('score des compétences proportionnel aux correspondances', () => {
    const offer = { requiredSkills: 'Plonge, Cuisine chaude' };
    const candidate = { skills: 'Plonge' };
    const { factors } = computeSparkScoreFactors(offer, candidate, undefined);
    expect(factors.skills.value).toBe(50);
  });

  test('aucune compétence requise = score compétences maximal', () => {
    const { factors } = computeSparkScoreFactors({}, { skills: '' }, undefined);
    expect(factors.skills.value).toBe(100);
  });

  test('disponibilité expirée ne compte pas comme disponible', () => {
    const candidate = {
      isAvailableNow: true,
      availableNowUntil: new Date(Date.now() - 86400000).toISOString(), // hier
    };
    const { factors } = computeSparkScoreFactors({}, candidate, undefined);
    expect(factors.availability.value).toBe(60);
  });

  test('coordonnées manquantes = score localisation neutre (70)', () => {
    const { factors } = computeSparkScoreFactors({}, {}, undefined);
    expect(factors.location.value).toBe(70);
  });

  test('pas de notes = score notes neutre basé sur 3.5/5', () => {
    const { factors } = computeSparkScoreFactors({}, {}, undefined);
    expect(factors.ratings.value).toBe(70); // 3.5/5 * 100
  });

  test('le score global reste borné entre 0 et 100', () => {
    const { globalScore } = computeSparkScoreFactors(
      { requiredSkills: 'A, B, C', salaryMin: 5000, salaryMax: 6000, latitude: 0, longitude: 0 },
      { skills: '', desiredSalaryMin: 1000, desiredSalaryMax: 1200, latitude: 50, longitude: 50 },
      { averageScore: 0, totalReviews: 0 }
    );
    expect(globalScore).toBeGreaterThanOrEqual(0);
    expect(globalScore).toBeLessThanOrEqual(100);
  });
});
