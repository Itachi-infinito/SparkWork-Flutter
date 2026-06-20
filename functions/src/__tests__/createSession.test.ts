import functionsTest from 'firebase-functions-test';

const test = functionsTest();

// ── Mocks ────────────────────────────────────────────────────────────────────

jest.mock('node-fetch', () => jest.fn());

const mockDocGet = jest.fn();
const mockDocSet = jest.fn();
const mockProfileQueryGet = jest.fn();

jest.mock('firebase-admin', () => {
  const firestoreMock: any = jest.fn(() => ({
    collection: jest.fn((name: string) => {
      if (name === 'verifications') {
        return {
          doc: jest.fn(() => ({ get: mockDocGet, set: mockDocSet })),
        };
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

// eslint-disable-next-line @typescript-eslint/no-require-imports
const fetchMock = require('node-fetch') as jest.Mock;

import { createVeriffSession } from '../veriff/createSession';

describe('createVeriffSession', () => {
  const wrapped = test.wrap(createVeriffSession);

  beforeEach(() => {
    process.env.VERIFF_API_KEY = 'test-api-key';
    mockProfileQueryGet.mockResolvedValue({ empty: true, docs: [] });
  });

  afterAll(() => test.cleanup());

  it('refuse un appel non authentifié', async () => {
    await expect(
      wrapped({ data: {}, auth: undefined } as any)
    ).rejects.toThrow(/unauthenticated|Authentication required/i);
  });

  it('refuse un documentType invalide', async () => {
    mockDocGet.mockResolvedValue({ exists: false, data: () => undefined });
    await expect(
      wrapped({ data: { documentType: 'FAKE_DOC' }, auth: { uid: 'user_1' } } as any)
    ).rejects.toThrow(/invalid-argument|Invalid document type/i);
  });

  it('crée une session avec succès et persiste sessionId + attemptCount', async () => {
    mockDocGet.mockResolvedValue({ exists: false, data: () => undefined });
    fetchMock.mockResolvedValue({
      ok: true,
      json: async () => ({
        status: 'created',
        verification: {
          id: 'sess_123',
          sessionToken: 'tok_abc',
          url: 'https://veriff.test/session/sess_123',
        },
      }),
    });

    const result = await wrapped({
      data: { documentType: 'NATIONAL_IDENTITY_CARD' },
      auth: { uid: 'user_1' },
    } as any);

    expect(result).toEqual({
      sessionUrl: 'https://veriff.test/session/sess_123',
      sessionId: 'sess_123',
    });
    expect(mockDocSet).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: 'user_1',
        sessionId: 'sess_123',
        status: 'pending',
        attemptCount: 1,
      }),
      { merge: true }
    );
  });

  it('échoue proprement sur une erreur réseau Veriff (réponse non-ok)', async () => {
    mockDocGet.mockResolvedValue({ exists: false, data: () => undefined });
    fetchMock.mockResolvedValue({
      ok: false,
      text: async () => 'Service Unavailable',
    });

    await expect(
      wrapped({ data: {}, auth: { uid: 'user_1' } } as any)
    ).rejects.toThrow(/internal|Failed to create verification session/i);
    expect(mockDocSet).not.toHaveBeenCalled();
  });

  it('échoue proprement si fetch rejette (panne réseau)', async () => {
    mockDocGet.mockResolvedValue({ exists: false, data: () => undefined });
    fetchMock.mockRejectedValue(new Error('ECONNRESET'));

    await expect(
      wrapped({ data: {}, auth: { uid: 'user_1' } } as any)
    ).rejects.toThrow();
  });

  it('refuse la création après 3 tentatives (attemptCount épuisé)', async () => {
    mockDocGet.mockResolvedValue({ exists: true, data: () => ({ attemptCount: 3 }) });

    await expect(
      wrapped({ data: {}, auth: { uid: 'user_1' } } as any)
    ).rejects.toThrow(/resource-exhausted|Maximum verification attempts/i);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('échoue si VERIFF_API_KEY n\'est pas configurée', async () => {
    delete process.env.VERIFF_API_KEY;
    mockDocGet.mockResolvedValue({ exists: false, data: () => undefined });

    await expect(
      wrapped({ data: {}, auth: { uid: 'user_1' } } as any)
    ).rejects.toThrow(/internal|not configured/i);
  });
});
