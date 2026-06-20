import { logger } from 'firebase-functions/v2';

/**
 * Résolution pays depuis une IP — best-effort via un service gratuit sans
 * clé API (faible volume). Échoue silencieusement (retourne null) en cas de
 * problème : la détection d'anomalie "pays inhabituel" est alors simplement
 * ignorée pour cette session, jamais bloquante.
 *
 * TODO: passer sur un fournisseur géo-IP payant (ex: ipinfo.io, MaxMind) si
 * le volume de connexions dépasse le tier gratuit de ipapi.co (~1000/jour).
 */
export async function lookupCountry(ip: string): Promise<string | null> {
  if (!ip || ip === '::1' || ip === '127.0.0.1') return null;
  try {
    const res = await fetch(`https://ipapi.co/${ip}/country_name/`, {
      signal: AbortSignal.timeout(3000),
    });
    if (!res.ok) return null;
    const text = (await res.text()).trim();
    if (!text || text.toLowerCase().includes('error') || text.toLowerCase().includes('undefined')) {
      return null;
    }
    return text;
  } catch (e) {
    logger.warn('lookupCountry failed', e);
    return null;
  }
}
