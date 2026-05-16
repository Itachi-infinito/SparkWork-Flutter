import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/job_offer.dart';
import '../services/database_service.dart';

final jobOfferRepositoryProvider = Provider<JobOfferRepository>((ref) {
  return JobOfferRepository(ref.read(databaseServiceProvider));
});

class JobOfferRepository {
  final DatabaseService _db;

  JobOfferRepository(this._db);

  Future<List<JobOffer>> getAllOffers() async {
    final db = await _db.database;
    final results = await db.query('job_offers');
    return results.map(JobOffer.fromMap).toList();
  }

  Future<List<JobOffer>> getOffersByRecruiter(int recruiterUserId) async {
    final db = await _db.database;
    final results = await db.query(
      'job_offers',
      where: 'recruiterUserId = ?',
      whereArgs: [recruiterUserId],
    );
    return results.map(JobOffer.fromMap).toList();
  }

  Future<JobOffer?> getOfferById(int jobOfferId) async {
    final db = await _db.database;
    final results = await db.query(
      'job_offers',
      where: 'jobOfferId = ?',
      whereArgs: [jobOfferId],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return JobOffer.fromMap(results.first);
  }

  Future<int> insertOffer(JobOffer offer) async {
    final db = await _db.database;
    final map = offer.toMap()..remove('jobOfferId');
    return db.insert('job_offers', map);
  }

  Future<void> updateOffer(JobOffer offer) async {
    final db = await _db.database;
    await db.update(
      'job_offers',
      offer.toMap(),
      where: 'jobOfferId = ?',
      whereArgs: [offer.jobOfferId],
    );
  }

  Future<void> deleteOffer(int jobOfferId) async {
    final db = await _db.database;
    await db.delete(
      'job_offers',
      where: 'jobOfferId = ?',
      whereArgs: [jobOfferId],
    );
  }
}