import 'package:flutter_test/flutter_test.dart';
import 'package:sparkwork/models/match.dart';

void main() {
  group('Match.status', () {
    test('reste "matched" tant que les deux parties n\'ont pas confirmé', () {
      const match = Match(
        matchId: 'm1', candidateUserId: 'c1', recruiterUserId: 'r1',
        jobOfferId: 'o1', candidateAnimationSeen: false,
        recruiterAnimationSeen: false, createdAt: '',
      );
      expect(match.status, 'matched');
      expect(match.isHiredConfirmed, isFalse);
    });

    test('reste "matched" si une seule des deux parties a confirmé', () {
      const match = Match(
        matchId: 'm1', candidateUserId: 'c1', recruiterUserId: 'r1',
        jobOfferId: 'o1', candidateAnimationSeen: false,
        recruiterAnimationSeen: false, createdAt: '',
        hiredByRecruiter: true,
      );
      expect(match.status, 'matched');
    });

    test('devient "hired" seulement quand les deux ont confirmé', () {
      const match = Match(
        matchId: 'm1', candidateUserId: 'c1', recruiterUserId: 'r1',
        jobOfferId: 'o1', candidateAnimationSeen: false,
        recruiterAnimationSeen: false, createdAt: '',
        hiredByRecruiter: true, hiredByCandidate: true,
      );
      expect(match.status, 'hired');
      expect(match.isHiredConfirmed, isTrue);
    });
  });

  group('Match.toMap/fromMap', () {
    test('conserve les données, y compris hiredAt si présent', () {
      const match = Match(
        matchId: 'm1', candidateUserId: 'c1', recruiterUserId: 'r1',
        jobOfferId: 'o1', candidateAnimationSeen: true,
        recruiterAnimationSeen: true, createdAt: '2026-01-01T00:00:00.000',
        hiredByRecruiter: true, hiredByCandidate: true,
        hiredAt: '2026-01-05T00:00:00.000',
      );
      final restored = Match.fromMap(match.toMap());

      expect(restored.matchId, match.matchId);
      expect(restored.hiredByRecruiter, isTrue);
      expect(restored.hiredByCandidate, isTrue);
      expect(restored.hiredAt, match.hiredAt);
      expect(restored.status, 'hired');
    });

    test('hiredAt absent du toMap si null', () {
      const match = Match(
        matchId: 'm1', candidateUserId: 'c1', recruiterUserId: 'r1',
        jobOfferId: 'o1', candidateAnimationSeen: false,
        recruiterAnimationSeen: false, createdAt: '',
      );
      expect(match.toMap().containsKey('hiredAt'), isFalse);
    });
  });
}
