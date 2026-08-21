import { Resend } from 'resend';
import { logger } from 'firebase-functions/v2';

const FROM = 'SparkWork <noreply@sparkwork.app>';

let _client: Resend | null = null;

function client(): Resend | null {
  if (_client) return _client;
  const key = process.env.RESEND_API_KEY;
  if (!key) return null;
  _client = new Resend(key);
  return _client;
}

export async function sendEmail(
  to: string,
  subject: string,
  html: string
): Promise<void> {
  const resend = client();
  if (!resend) {
    logger.warn(`[email] RESEND_API_KEY not set — skipping email to ${to}: "${subject}"`);
    return;
  }
  const { error } = await resend.emails.send({ from: FROM, to, subject, html });
  if (error) {
    logger.error(`[email] Failed to send "${subject}" to ${to}`, error);
    throw new Error(error.message);
  }
  logger.info(`[email] Sent "${subject}" to ${to}`);
}
