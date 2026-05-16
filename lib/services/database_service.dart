import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/user.dart';
import '../models/candidate_profile.dart';
import '../models/job_offer.dart';
import '../models/match.dart';
import '../models/message.dart';

class DatabaseService {
  Database? _db;

  Future<Database> get database async {
    _db ??= await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'sparkwork.db');
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''CREATE TABLE users(
      userId INTEGER PRIMARY KEY AUTOINCREMENT,
      fullName TEXT NOT NULL, email TEXT NOT NULL UNIQUE,
      passwordHash TEXT NOT NULL, role TEXT NOT NULL)''');

    await db.execute('''CREATE TABLE candidate_profiles(
      profileId INTEGER PRIMARY KEY AUTOINCREMENT,
      userId INTEGER NOT NULL, fullName TEXT, email TEXT, bio TEXT DEFAULT '',
      skills TEXT DEFAULT '', desiredContractType TEXT DEFAULT '',
      experienceLevel TEXT DEFAULT '', desiredSalaryMin INTEGER DEFAULT 0,
      desiredSalaryMax INTEGER DEFAULT 0, maxDistanceKm INTEGER DEFAULT 25,
      latitude REAL DEFAULT 0, longitude REAL DEFAULT 0,
      experienceTitle1 TEXT DEFAULT '', experienceCompany1 TEXT DEFAULT '',
      experiencePeriod1 TEXT DEFAULT '', experienceTitle2 TEXT DEFAULT '',
      experienceCompany2 TEXT DEFAULT '', experiencePeriod2 TEXT DEFAULT '')''');

    await db.execute('''CREATE TABLE job_offers(
      jobOfferId INTEGER PRIMARY KEY AUTOINCREMENT,
      recruiterUserId INTEGER NOT NULL, title TEXT NOT NULL,
      companyName TEXT NOT NULL, location TEXT DEFAULT '', contractType TEXT DEFAULT '',
      description TEXT DEFAULT '', address TEXT DEFAULT '',
      latitude REAL DEFAULT 0, longitude REAL DEFAULT 0,
      salaryMin INTEGER DEFAULT 0, salaryMax INTEGER DEFAULT 0,
      requiredSkills TEXT DEFAULT '', niceToHaveSkills TEXT DEFAULT '',
      remoteMode TEXT DEFAULT '', level TEXT DEFAULT '')''');

    await db.execute('''CREATE TABLE matches(
      matchId INTEGER PRIMARY KEY AUTOINCREMENT,
      candidateUserId INTEGER NOT NULL, candidateName TEXT NOT NULL,
      recruiterUserId INTEGER NOT NULL, companyName TEXT NOT NULL,
      jobTitle TEXT NOT NULL, jobOfferId INTEGER NOT NULL,
      animationSeenByCandidate INTEGER DEFAULT 0,
      animationSeenByRecruiter INTEGER DEFAULT 0)''');

    await db.execute('''CREATE TABLE messages(
      messageId INTEGER PRIMARY KEY AUTOINCREMENT,
      matchId INTEGER NOT NULL, senderUserId INTEGER NOT NULL,
      content TEXT NOT NULL, sentAt TEXT NOT NULL)''');

    await db.execute('''CREATE TABLE candidate_job_likes(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      candidateUserId INTEGER NOT NULL, jobOfferId INTEGER NOT NULL)''');

    await db.execute('''CREATE TABLE recruiter_candidate_likes(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      recruiterUserId INTEGER NOT NULL, candidateUserId INTEGER NOT NULL,
      isSuperLike INTEGER DEFAULT 0)''');
  }

  Future<int> insertUser(User u) async {
    final db = await database;
    return db.insert('users', u.toMap());
  }

  Future<User?> getUserByEmail(String email) async {
    final db = await database;
    final rows = await db.query('users', where: 'email = ?', whereArgs: [email]);
    if (rows.isEmpty) return null;
    return User.fromMap(rows.first);
  }

  Future<User?> getUserById(int id) async {
    final db = await database;
    final rows = await db.query('users', where: 'userId = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return User.fromMap(rows.first);
  }
}

final databaseServiceProvider = Provider<DatabaseService>((ref) => DatabaseService());
