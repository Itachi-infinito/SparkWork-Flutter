import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'sparkwork.db');

    return openDatabase(
      path,
      version: 2,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE recruiter_candidate_likes ADD COLUMN isSuperLike INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        userId INTEGER PRIMARY KEY AUTOINCREMENT,
        fullName TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        passwordHash TEXT NOT NULL,
        role TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE candidate_profiles (
        profileId INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL UNIQUE,
        fullName TEXT NOT NULL,
        location TEXT NOT NULL DEFAULT '',
        desiredContractType TEXT NOT NULL DEFAULT '',
        desiredLevel TEXT NOT NULL DEFAULT '',
        skills TEXT NOT NULL DEFAULT '',
        bio TEXT NOT NULL DEFAULT '',
        desiredSalaryMin INTEGER NOT NULL DEFAULT 0,
        desiredSalaryMax INTEGER NOT NULL DEFAULT 0,
        remotePreference TEXT NOT NULL DEFAULT '',
        latitude REAL NOT NULL DEFAULT 0,
        longitude REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (userId) REFERENCES users(userId)
      )
    ''');

    await db.execute('''
      CREATE TABLE job_offers (
        jobOfferId INTEGER PRIMARY KEY AUTOINCREMENT,
        recruiterUserId INTEGER NOT NULL,
        title TEXT NOT NULL,
        companyName TEXT NOT NULL,
        location TEXT NOT NULL,
        contractType TEXT NOT NULL,
        description TEXT NOT NULL,
        address TEXT NOT NULL DEFAULT '',
        latitude REAL NOT NULL DEFAULT 0,
        longitude REAL NOT NULL DEFAULT 0,
        salaryMin INTEGER NOT NULL DEFAULT 0,
        salaryMax INTEGER NOT NULL DEFAULT 0,
        requiredSkills TEXT NOT NULL DEFAULT '',
        niceToHaveSkills TEXT NOT NULL DEFAULT '',
        remoteMode TEXT NOT NULL DEFAULT '',
        level TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (recruiterUserId) REFERENCES users(userId)
      )
    ''');

    await db.execute('''
      CREATE TABLE matches (
        matchId INTEGER PRIMARY KEY AUTOINCREMENT,
        candidateUserId INTEGER NOT NULL,
        recruiterUserId INTEGER NOT NULL,
        jobOfferId INTEGER NOT NULL,
        candidateAnimationSeen INTEGER NOT NULL DEFAULT 0,
        recruiterAnimationSeen INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (candidateUserId) REFERENCES users(userId),
        FOREIGN KEY (recruiterUserId) REFERENCES users(userId),
        FOREIGN KEY (jobOfferId) REFERENCES job_offers(jobOfferId)
      )
    ''');

    await db.execute('''
      CREATE TABLE messages (
        messageId INTEGER PRIMARY KEY AUTOINCREMENT,
        matchId INTEGER NOT NULL,
        senderUserId INTEGER NOT NULL,
        content TEXT NOT NULL,
        sentAt TEXT NOT NULL,
        FOREIGN KEY (matchId) REFERENCES matches(matchId)
      )
    ''');

    await db.execute('''
      CREATE TABLE candidate_job_likes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        candidateUserId INTEGER NOT NULL,
        jobOfferId INTEGER NOT NULL,
        UNIQUE(candidateUserId, jobOfferId)
      )
    ''');

    await db.execute('''
      CREATE TABLE recruiter_candidate_likes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recruiterUserId INTEGER NOT NULL,
        candidateUserId INTEGER NOT NULL,
        jobOfferId INTEGER NOT NULL,
        isSuperLike INTEGER NOT NULL DEFAULT 0,
        UNIQUE(recruiterUserId, candidateUserId, jobOfferId)
      )
    ''');
  }

  Future<User?> getUserByEmail(String email) async {
    final db = await database;
    final results = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return User.fromMap(results.first);
  }

  Future<User?> getUserById(int userId) async {
    final db = await database;
    final results = await db.query(
      'users',
      where: 'userId = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return User.fromMap(results.first);
  }

  Future<int> insertUser(Map<String, dynamic> userMap) async {
    final db = await database;
    return db.insert('users', userMap);
  }
}