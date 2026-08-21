/**
 * Correspondance produit RevenueCat -> plan SparkWork.
 * Partagé entre le webhook (événements asynchrones) et la réconciliation
 * synchrone (syncSubscriptionStatus) pour garantir une logique unique.
 */
export const PRODUCT_TO_PLAN: Record<string, string> = {
  sparkwork_starter_monthly: 'starter',
  sparkwork_pro_monthly: 'pro',
};

/** Priorité de plan : le plan le plus élevé l'emporte si plusieurs actifs. */
const PLAN_RANK: Record<string, number> = { free: 0, starter: 1, pro: 2 };

export function planFromProductId(productId: string | undefined): string | null {
  if (!productId) return null;
  return PRODUCT_TO_PLAN[productId] ?? null;
}

/** Retourne le plan le plus élevé parmi deux plans (par rang). */
export function highestPlan(a: string, b: string): string {
  return (PLAN_RANK[a] ?? 0) >= (PLAN_RANK[b] ?? 0) ? a : b;
}
