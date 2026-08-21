const BRAND_COLOR = '#7C3AED';
const BRAND_DARK = '#5B21B6';

function baseLayout(content: string): string {
  return `
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>SparkWork</title>
</head>
<body style="margin:0;padding:0;background:#F3F4F6;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#F3F4F6;padding:32px 0;">
    <tr><td align="center">
      <table width="540" cellpadding="0" cellspacing="0" style="max-width:540px;width:100%;">

        <!-- Header -->
        <tr>
          <td style="background:linear-gradient(135deg,#1E0A3C,${BRAND_COLOR});border-radius:16px 16px 0 0;padding:32px;text-align:center;">
            <div style="display:inline-block;background:rgba(255,255,255,0.12);border-radius:16px;padding:14px 18px;border:1px solid rgba(255,255,255,0.2);">
              <span style="font-size:28px;">⚡</span>
            </div>
            <div style="color:#fff;font-size:22px;font-weight:700;margin-top:12px;letter-spacing:-0.5px;">SparkWork</div>
          </td>
        </tr>

        <!-- Body -->
        <tr>
          <td style="background:#fff;padding:40px 36px;border-radius:0 0 16px 16px;box-shadow:0 4px 24px rgba(0,0,0,0.08);">
            ${content}
          </td>
        </tr>

        <!-- Footer -->
        <tr>
          <td style="padding:24px;text-align:center;color:#9CA3AF;font-size:12px;line-height:1.6;">
            SparkWork — Le recrutement réinventé<br/>
            Des questions ? <a href="mailto:contact@sparkwork.app" style="color:${BRAND_COLOR};text-decoration:none;">contact@sparkwork.app</a>
          </td>
        </tr>

      </table>
    </td></tr>
  </table>
</body>
</html>`;
}

export function otpUnlockEmail(code: string, ttlMinutes = 10): string {
  const content = `
    <h2 style="margin:0 0 8px;color:#111827;font-size:22px;font-weight:700;">Déverrouillez votre compte</h2>
    <p style="margin:0 0 28px;color:#6B7280;font-size:15px;line-height:1.6;">
      Votre compte SparkWork a été temporairement restreint pour protéger votre sécurité.
      Entrez le code ci-dessous dans l'application pour retrouver un accès complet.
    </p>

    <!-- OTP box -->
    <div style="background:#F5F3FF;border:2px solid ${BRAND_COLOR};border-radius:12px;padding:28px;text-align:center;margin:0 0 28px;">
      <div style="color:${BRAND_DARK};font-size:11px;font-weight:600;letter-spacing:2px;text-transform:uppercase;margin-bottom:12px;">Votre code de déblocage</div>
      <div style="color:${BRAND_COLOR};font-size:44px;font-weight:800;letter-spacing:10px;font-variant-numeric:tabular-nums;">${code}</div>
      <div style="color:#9CA3AF;font-size:12px;margin-top:10px;">Valide pendant ${ttlMinutes} minutes</div>
    </div>

    <p style="margin:0 0 20px;color:#6B7280;font-size:13px;line-height:1.6;">
      Si vous n'êtes pas à l'origine de cette demande, ignorez cet email et
      <a href="mailto:contact@sparkwork.app" style="color:${BRAND_COLOR};text-decoration:none;">contactez notre support</a> immédiatement.
    </p>
    <hr style="border:none;border-top:1px solid #E5E7EB;margin:0;" />
    <p style="margin:20px 0 0;color:#9CA3AF;font-size:12px;">
      Ce code est strictement personnel. SparkWork ne vous demandera jamais votre code par téléphone ou email.
    </p>
  `;
  return baseLayout(content);
}

export function teamUpsellEmail(distinctDevices: number, forcedByRestriction: boolean): string {
  const reason = forcedByRestriction
    ? 'Votre compte a été restreint plusieurs fois en raison de connexions depuis de multiples appareils.'
    : `Nous avons détecté <strong>${distinctDevices} appareils distincts</strong> connectés à votre compte ces 30 derniers jours.`;

  const content = `
    <h2 style="margin:0 0 8px;color:#111827;font-size:22px;font-weight:700;">Plusieurs personnes utilisent votre compte ?</h2>
    <p style="margin:0 0 24px;color:#6B7280;font-size:15px;line-height:1.6;">
      ${reason}
    </p>

    <!-- Feature list -->
    <div style="background:#F9FAFB;border-radius:12px;padding:24px;margin:0 0 28px;">
      <div style="color:#111827;font-size:14px;font-weight:600;margin-bottom:16px;">Avec SparkWork Équipe Pro, vous pouvez :</div>
      ${['Ajouter jusqu\'à 5 membres dans votre espace recruteur', 'Gérer les permissions de chaque collaborateur', 'Voir qui publie quelles offres et qui swipe', 'Centraliser la facturation en un seul abonnement'].map(
        (f) => `<div style="display:flex;align-items:center;margin-bottom:10px;">
          <span style="color:#10B981;font-size:16px;margin-right:10px;">✓</span>
          <span style="color:#374151;font-size:14px;">${f}</span>
        </div>`
      ).join('')}
    </div>

    <div style="text-align:center;">
      <a href="https://sparkwork.app/upgrade" style="display:inline-block;background:linear-gradient(135deg,${BRAND_DARK},${BRAND_COLOR});color:#fff;font-size:15px;font-weight:700;text-decoration:none;padding:14px 36px;border-radius:10px;">
        Découvrir l'offre Équipe Pro
      </a>
    </div>

    <p style="margin:24px 0 0;color:#9CA3AF;font-size:12px;text-align:center;line-height:1.6;">
      Si vous utilisez seul votre compte et que ces alertes vous semblent incorrectes,
      <a href="mailto:contact@sparkwork.app" style="color:${BRAND_COLOR};text-decoration:none;">contactez notre support</a>.
    </p>
  `;
  return baseLayout(content);
}
