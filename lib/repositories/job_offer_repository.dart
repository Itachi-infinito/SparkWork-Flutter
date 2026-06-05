import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/job_offer.dart';

final jobOfferRepositoryProvider = Provider<JobOfferRepository>((ref) {
  return JobOfferRepository();
});

class JobOfferRepository {
  final _col = FirebaseFirestore.instance.collection('job_offers');

  JobOffer _fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JobOffer.fromMap({...data, 'jobOfferId': doc.id});
  }

  Future<List<JobOffer>> getAllActiveOffers() async {
    final q = await _col.where('isActive', isEqualTo: true).get();
    return q.docs.map(_fromDoc).toList();
  }

  Future<List<JobOffer>> getAllOffers() => getAllActiveOffers();

  Future<List<JobOffer>> getOffersByRecruiter(String recruiterUserId) async {
    final q = await _col
        .where('recruiterUserId', isEqualTo: recruiterUserId)
        .get();
    return q.docs.map(_fromDoc).toList();
  }

  Future<JobOffer?> getOfferById(String jobOfferId) async {
    final doc = await _col.doc(jobOfferId).get();
    if (!doc.exists) return null;
    return _fromDoc(doc);
  }

  Future<String> createOffer(JobOffer offer) async {
    final map = offer.toMap()..remove('jobOfferId');
    map['isActive'] = true;
    map['createdAt'] = FieldValue.serverTimestamp();
    final ref = await _col.add(map);
    return ref.id;
  }

  Future<void> insertOffer(JobOffer offer) async {
    await createOffer(offer);
  }

  Future<void> updateOffer(JobOffer offer) async {
    final map = offer.toMap()..remove('jobOfferId');
    await _col.doc(offer.jobOfferId).update(map);
  }

  Future<void> deleteOffer(String jobOfferId) async {
    await _col.doc(jobOfferId).delete();
  }
}