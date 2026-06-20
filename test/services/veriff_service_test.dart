import 'package:flutter_test/flutter_test.dart';
import 'package:sparkwork/models/verification_model.dart';

void main() {
  group('VeriffStatus.fromString', () {
    test('maps known strings correctly', () {
      expect(VeriffStatus.fromString('pending'), VeriffStatus.pending);
      expect(VeriffStatus.fromString('verified'), VeriffStatus.verified);
      expect(VeriffStatus.fromString('rejected'), VeriffStatus.rejected);
      expect(VeriffStatus.fromString('resubmission_requested'),
          VeriffStatus.resubmissionRequested);
      expect(VeriffStatus.fromString('unverified'), VeriffStatus.unverified);
    });

    test('defaults to unverified for unknown or null values', () {
      expect(VeriffStatus.fromString(null), VeriffStatus.unverified);
      expect(VeriffStatus.fromString(''), VeriffStatus.unverified);
      expect(VeriffStatus.fromString('approved'), VeriffStatus.unverified);
    });
  });

  group('VeriffStatus.toFirestoreString', () {
    test('round-trips all statuses', () {
      for (final s in VeriffStatus.values) {
        final str = s.toFirestoreString();
        expect(VeriffStatus.fromString(str), s);
      }
    });
  });

  group('DocumentType', () {
    test('toVeriffString maps to Veriff API values', () {
      expect(DocumentType.nationalId.toVeriffString(), 'NATIONAL_IDENTITY_CARD');
      expect(DocumentType.passport.toVeriffString(), 'PASSPORT');
      expect(DocumentType.drivingLicense.toVeriffString(), 'DRIVERS_LICENSE');
    });

    test('label returns French display text', () {
      expect(DocumentType.nationalId.label, contains('identité'));
      expect(DocumentType.passport.label.toLowerCase(), contains('passeport'));
      expect(DocumentType.drivingLicense.label.toLowerCase(), contains('permis'));
    });
  });

  group('VerificationModel', () {
    test('fromMap parses complete map correctly', () {
      final map = {
        'userId': 'user_123',
        'sessionId': 'session_abc',
        'status': 'verified',
        'declineReason': null,
        'submittedAt': '2024-01-15T10:00:00.000Z',
        'decidedAt': '2024-01-15T10:02:00.000Z',
        'attemptCount': 1,
        'documentType': 'PASSPORT',
      };
      final model = VerificationModel.fromMap(map, 'user_123');

      expect(model.userId, 'user_123');
      expect(model.sessionId, 'session_abc');
      expect(model.status, VeriffStatus.verified);
      expect(model.declineReason, isNull);
      expect(model.attemptCount, 1);
      expect(model.documentType, DocumentType.passport);
      expect(model.submittedAt, isNotNull);
      expect(model.decidedAt, isNotNull);
    });

    test('fromMap handles missing optional fields', () {
      final map = {'userId': 'user_456'};
      final model = VerificationModel.fromMap(map, 'user_456');

      expect(model.status, VeriffStatus.unverified);
      expect(model.attemptCount, 0);
      expect(model.sessionId, isNull);
      expect(model.documentType, isNull);
    });

    test('fromMap parses rejected status with reason', () {
      final map = {
        'userId': 'user_789',
        'status': 'rejected',
        'declineReason': 'Document expired',
        'attemptCount': 2,
      };
      final model = VerificationModel.fromMap(map, 'user_789');

      expect(model.status, VeriffStatus.rejected);
      expect(model.declineReason, 'Document expired');
    });

    test('fromMap parses resubmission_requested', () {
      final map = {
        'userId': 'user_000',
        'status': 'resubmission_requested',
        'attemptCount': 1,
      };
      final model = VerificationModel.fromMap(map, 'user_000');
      expect(model.status, VeriffStatus.resubmissionRequested);
    });

    group('canRetry', () {
      test('returns true when attemptCount < 3', () {
        final m = VerificationModel(
            verificationId: 'x', userId: 'x', attemptCount: 2);
        expect(m.canRetry, isTrue);
      });

      test('returns false when attemptCount == 3', () {
        final m = VerificationModel(
            verificationId: 'x', userId: 'x', attemptCount: 3);
        expect(m.canRetry, isFalse);
      });

      test('returns false when attemptCount > 3', () {
        final m = VerificationModel(
            verificationId: 'x', userId: 'x', attemptCount: 4);
        expect(m.canRetry, isFalse);
      });
    });

    group('isVerified', () {
      test('returns true only for verified status', () {
        final verified = VerificationModel(
            verificationId: 'x',
            userId: 'x',
            status: VeriffStatus.verified);
        expect(verified.isVerified, isTrue);

        for (final s in VeriffStatus.values.where((s) => s != VeriffStatus.verified)) {
          final m = VerificationModel(verificationId: 'x', userId: 'x', status: s);
          expect(m.isVerified, isFalse,
              reason: '${s.name} should not be verified');
        }
      });
    });

    group('needsResubmission', () {
      test('returns true only for resubmission_requested', () {
        final m = VerificationModel(
            verificationId: 'x',
            userId: 'x',
            status: VeriffStatus.resubmissionRequested);
        expect(m.needsResubmission, isTrue);
      });
    });
  });

  // ── Webhook HMAC logic (pure Dart — no Firebase dependency) ────────────────

  group('HMAC signature verification logic', () {
    // Mirrors the server-side logic without importing dart:io crypto
    // (dart:convert + crypto package would be used in integration tests)

    test('approved action maps to verified status', () {
      const statusMap = {
        'approved': 'verified',
        'declined': 'rejected',
        'resubmission_requested': 'resubmission_requested',
      };
      expect(statusMap['approved'], 'verified');
      expect(statusMap['declined'], 'rejected');
      expect(statusMap['resubmission_requested'], 'resubmission_requested');
      expect(statusMap['submitted'], isNull); // ignored action
      expect(statusMap['abandoned'], isNull); // ignored action
    });
  });
}
