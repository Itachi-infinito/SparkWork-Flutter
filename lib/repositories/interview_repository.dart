import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/interview.dart';

final interviewRepositoryProvider =
    Provider<InterviewRepository>((ref) => InterviewRepository());

class InterviewRepository {
  final _col = FirebaseFirestore.instance.collection('interviews');

  Interview _fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Interview.fromMap({...data, 'interviewId': doc.id});
  }

  /// Dernière proposition pour un match (une seule active à la fois).
  /// Tri côté client pour éviter un index composite where+orderBy.
  Future<Interview?> getForMatch(String matchId) async {
    final q = await _col.where('matchId', isEqualTo: matchId).get();
    if (q.docs.isEmpty) return null;
    final all = q.docs.map(_fromDoc).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all.first;
  }

  /// Crée une proposition. S'il existe déjà une proposition non acceptée
  /// pour ce match, elle est remplacée (re-proposition de créneaux).
  Future<String> propose({
    required String matchId,
    required String recruiterUserId,
    required String candidateUserId,
    required List<DateTime> slots,
    String message = '',
  }) async {
    final existing = await _col.where('matchId', isEqualTo: matchId).get();
    for (final doc in existing.docs) {
      final status = (doc.data() as Map<String, dynamic>)['status'] as String?;
      if (status != 'accepted') await doc.reference.delete();
    }
    final ref = await _col.add({
      'matchId': matchId,
      'recruiterUserId': recruiterUserId,
      'candidateUserId': candidateUserId,
      'slots': slots.map((d) => d.toIso8601String()).toList(),
      'acceptedSlot': '',
      'status': 'pending',
      'message': message,
      'createdAt': DateTime.now().toIso8601String(),
    });
    return ref.id;
  }

  /// Le candidat accepte un créneau.
  Future<void> accept(String interviewId, DateTime slot) async {
    await _col.doc(interviewId).update({
      'acceptedSlot': slot.toIso8601String(),
      'status': 'accepted',
    });
  }

  /// Le candidat décline la proposition.
  Future<void> decline(String interviewId) async {
    await _col.doc(interviewId).update({'status': 'declined'});
  }

  /// Le recruteur annule sa proposition (ou un entretien confirmé).
  Future<void> cancel(String interviewId) async {
    await _col.doc(interviewId).update({'status': 'cancelled'});
  }
}
