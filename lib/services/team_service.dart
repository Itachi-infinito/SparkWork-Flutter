import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/team.dart';
import '../models/subscription.dart';
import 'subscription_service.dart';

final teamServiceProvider =
    Provider<TeamService>((ref) => TeamService(ref.read(subscriptionServiceProvider)));

class TeamService {
  final SubscriptionService _subSvc;
  TeamService(this._subSvc);

  final _db = FirebaseFirestore.instance;

  Future<void> _requirePro(String userId) async {
    final plan = await _subSvc.getCurrentPlan(userId);
    if (plan != SubscriptionPlan.pro) {
      throw Exception('La fonctionnalité Équipe est réservée au plan Pro.');
    }
  }

  /// Crée une équipe pour un recruteur (devient owner).
  Future<Team> createTeam(String ownerId, {String? ownerName, String? ownerEmail}) async {
    await _requirePro(ownerId);
    final docRef = _db.collection('teams').doc();
    final now = DateTime.now().toIso8601String();
    final member = TeamMember(
      userId: ownerId,
      role: 'owner',
      joinedAt: now,
      displayName: ownerName,
      email: ownerEmail,
    );
    final team = Team(
      teamId: docRef.id,
      companyId: ownerId,
      members: [member],
      createdAt: now,
    );
    await docRef.set(team.toMap());
    return team;
  }

  Future<Team?> getTeamByOwner(String ownerId) async {
    try {
      final q = await _db
          .collection('teams')
          .where('companyId', isEqualTo: ownerId)
          .limit(1)
          .get();
      if (q.docs.isEmpty) return null;
      return Team.fromMap(q.docs.first.data());
    } catch (_) {
      return null;
    }
  }

  Future<Team?> getTeamByMember(String userId) async {
    try {
      final q = await _db.collection('teams').get();
      for (final doc in q.docs) {
        final team = Team.fromMap(doc.data());
        if (team.isMember(userId)) return team;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Invite un membre par email (crée un enregistrement d'invitation).
  Future<void> inviteMember(String teamId, String inviterUserId, String email, String role) async {
    await _db.collection('team_invitations').add({
      'teamId': teamId,
      'inviterUserId': inviterUserId,
      'email': email,
      'role': role,
      'status': 'pending',
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> removeMember(String teamId, String userId) async {
    final doc = await _db.collection('teams').doc(teamId).get();
    if (!doc.exists) return;
    final team = Team.fromMap(doc.data()!);
    final updated = team.members.where((m) => m.userId != userId).toList();
    await _db.collection('teams').doc(teamId).update({
      'members': updated.map((m) => m.toMap()).toList(),
    });
  }

  // ─── Votes ────────────────────────────────────────────────────────────────

  Future<void> castVote({
    required String teamId,
    required String offerId,
    required String candidateId,
    required String voterId,
    required SwipeVoteType vote,
    String? note,
    String? voterName,
  }) async {
    final existingQ = await _db
        .collection('swipe_votes')
        .where('teamId', isEqualTo: teamId)
        .where('offerId', isEqualTo: offerId)
        .where('candidateId', isEqualTo: candidateId)
        .where('voterId', isEqualTo: voterId)
        .limit(1)
        .get();

    final now = DateTime.now().toIso8601String();
    if (existingQ.docs.isNotEmpty) {
      await existingQ.docs.first.reference.update({
        'vote': vote.value,
        if (note != null) 'note': note,
        'createdAt': now,
      });
    } else {
      final ref = _db.collection('swipe_votes').doc();
      await ref.set(SwipeVote(
        voteId: ref.id,
        teamId: teamId,
        offerId: offerId,
        candidateId: candidateId,
        voterId: voterId,
        vote: vote.value,
        note: note,
        createdAt: now,
        voterName: voterName,
      ).toMap());
    }
  }

  Future<List<SwipeVote>> getVotesForCandidate({
    required String teamId,
    required String offerId,
    required String candidateId,
  }) async {
    try {
      final q = await _db
          .collection('swipe_votes')
          .where('teamId', isEqualTo: teamId)
          .where('offerId', isEqualTo: offerId)
          .where('candidateId', isEqualTo: candidateId)
          .get();
      return q.docs.map((d) => SwipeVote.fromMap(d.data())).toList();
    } catch (_) {
      return [];
    }
  }

  Future<SwipeVote?> getMyVote({
    required String teamId,
    required String offerId,
    required String candidateId,
    required String voterId,
  }) async {
    try {
      final q = await _db
          .collection('swipe_votes')
          .where('teamId', isEqualTo: teamId)
          .where('offerId', isEqualTo: offerId)
          .where('candidateId', isEqualTo: candidateId)
          .where('voterId', isEqualTo: voterId)
          .limit(1)
          .get();
      if (q.docs.isEmpty) return null;
      return SwipeVote.fromMap(q.docs.first.data());
    } catch (_) {
      return null;
    }
  }
}
