import 'package:flutter_test/flutter_test.dart';
import 'package:sparkwork/models/spark_invite.dart';

void main() {
  group('SparkInvite', () {
    test('toMap/fromMap conservent les données', () {
      const invite = SparkInvite(
        inviteId: 'i1',
        senderId: 'recruiter1',
        receiverId: 'candidate1',
        offerId: 'offer1',
        sentAt: '2026-01-01T00:00:00.000',
        status: 'viewed',
      );
      final restored = SparkInvite.fromMap(invite.toMap(), 'i1');

      expect(restored.senderId, invite.senderId);
      expect(restored.receiverId, invite.receiverId);
      expect(restored.offerId, invite.offerId);
      expect(restored.sentAt, invite.sentAt);
      expect(restored.status, invite.status);
    });

    test('status par défaut = pending', () {
      const invite = SparkInvite(
        inviteId: 'i1', senderId: 's', receiverId: 'r', offerId: 'o', sentAt: '',
      );
      expect(invite.status, 'pending');
    });

    test('fromMap retombe sur des valeurs par défaut si champs manquants', () {
      final invite = SparkInvite.fromMap({}, 'docId');
      expect(invite.inviteId, 'docId');
      expect(invite.status, 'pending');
      expect(invite.senderId, '');
    });
  });
}
