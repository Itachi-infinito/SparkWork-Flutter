import * as crypto from 'crypto';

const mockVerificationUpdate = jest.fn();
const mockProfileRefUpdate = jest.fn();
const mockProfileQueryGet = jest.fn();

jest.mock('firebase-admin', () => {
  const firestoreMock: any = jest.fn(() => ({
    collection: jest.fn((name: string) => {
      if (name === 'verifications') {
        return { doc: jest.fn(() => ({ update: mockVerificationUpdate })) };
      }
      if (name === 'candidate_profiles') {
        return {
          where: jest.fn(() => ({
            limit: jest.fn(() => ({ get: mockProfileQueryGet })),
          })),
        };
      }
      throw new Error(`Unexpected collection in test: ${name}`);
    }),
  }));
  firestoreMock.FieldValue = { serverTimestamp: jest.fn(() => 'SERVER_TIMESTAMP') };
  return { initializeApp: jest.fn(), firestore: firestoreMock };
});

import { veriffWebhook } from '../veriff/webhook';

function makeRes() {
  const res: any = {};
  res.status = jest.fn().mockReturnValue(res);
  res.send = jest.fn().mockReturnValue(res);
  return res;
}

function sign(secret: string, body: unknown): string {
  return crypto.createHmac('sha256', secret).update(JSON.stringify(body)).digest('hex');
}

async function callWebhook(body: any, signature?: string) {
  const res = makeRes();
  const req: any = {
    method: 'POST',
    body,
    headers: signature ? { 'x-hmac-signature': signature } : {},
  };
  // onRequest() v2 wraps the handler but the resulting export is directly
  // callable as (req, res) — no firebase-functions-test wrap needed for HTTP.
  await (veriffWebhook as unknown as (req: any, res: any) => Promise<void>)(req, res);
  return res;
}

describe('veriffWebhook', () => {
  const secret = 'whsec_test_value';

  beforeEach(() => {
    process.env.VERIFF_WEBHOOK_SECRET = secret;
    mockProfileQueryGet.mockResolvedValue({
      empty: false,
      docs: [{ ref: { update: mockProfileRefUpdate } }],
    });
  });

  it('rejette une requête non-POST', async () => {
    const res = makeRes();
    const req: any = { method: 'GET', body: {}, headers: {} };
    await (veriffWebhook as unknown as (req: any, res: any) => Promise<void>)(req, res);
    expect(res.status).toHaveBeenCalledWith(405);
  });

  it('rejette une requête sans en-tête de signature', async () => {
    const body = { action: 'approved', verification: { id: 's1', vendorData: 'user1' } };
    const res = await callWebhook(body);
    expect(res.status).toHaveBeenCalledWith(401);
    expect(mockVerificationUpdate).not.toHaveBeenCalled();
  });

  it('rejette une signature HMAC invalide', async () => {
    const body = { action: 'approved', verification: { id: 's1', vendorData: 'user1' } };
    const res = await callWebhook(body, 'a'.repeat(64)); // hex valide mais faux
    expect(res.status).toHaveBeenCalledWith(401);
    expect(mockVerificationUpdate).not.toHaveBeenCalled();
  });

  it('accepte une signature HMAC valide et traite la décision approved', async () => {
    const body = { action: 'approved', verification: { id: 's1', vendorData: 'user1' } };
    const res = await callWebhook(body, sign(secret, body));

    expect(res.status).toHaveBeenCalledWith(200);
    expect(mockVerificationUpdate).toHaveBeenCalledWith(
      expect.objectContaining({ status: 'verified', sessionId: 's1' })
    );
    expect(mockProfileRefUpdate).toHaveBeenCalledWith(
      expect.objectContaining({ verificationStatus: 'verified' })
    );
  });

  it('traite la décision declined avec le motif de refus', async () => {
    const body = {
      action: 'declined',
      verification: { id: 's2', vendorData: 'user2', reason: 'Document expiré' },
    };
    const res = await callWebhook(body, sign(secret, body));

    expect(res.status).toHaveBeenCalledWith(200);
    expect(mockVerificationUpdate).toHaveBeenCalledWith(
      expect.objectContaining({ status: 'rejected', declineReason: 'Document expiré' })
    );
    expect(mockProfileRefUpdate).toHaveBeenCalledWith(
      expect.objectContaining({
        verificationStatus: 'rejected',
        verificationRejectionReason: 'Document expiré',
      })
    );
  });

  it('traite resubmission_requested', async () => {
    const body = {
      action: 'resubmission_requested',
      verification: { id: 's3', vendorData: 'user3' },
    };
    const res = await callWebhook(body, sign(secret, body));

    expect(res.status).toHaveBeenCalledWith(200);
    expect(mockVerificationUpdate).toHaveBeenCalledWith(
      expect.objectContaining({ status: 'resubmission_requested' })
    );
  });

  it('ignore une action inconnue sans toucher Firestore (ex: submitted, abandoned)', async () => {
    const body = { action: 'submitted', verification: { id: 's4', vendorData: 'user4' } };
    const res = await callWebhook(body, sign(secret, body));

    expect(res.status).toHaveBeenCalledWith(200);
    expect(mockVerificationUpdate).not.toHaveBeenCalled();
  });

  it('renvoie 500 si VERIFF_WEBHOOK_SECRET n\'est pas configuré', async () => {
    delete process.env.VERIFF_WEBHOOK_SECRET;
    const body = { action: 'approved', verification: { id: 's5', vendorData: 'user5' } };
    const res = await callWebhook(body, 'whatever');
    expect(res.status).toHaveBeenCalledWith(500);
  });

  it('renvoie 400 si vendorData est manquant', async () => {
    const body = { action: 'approved', verification: { id: 's6' } };
    const res = await callWebhook(body, sign(secret, body));
    expect(res.status).toHaveBeenCalledWith(400);
  });
});
