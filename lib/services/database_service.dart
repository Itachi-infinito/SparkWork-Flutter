import 'package:flutter_riverpod/flutter_riverpod.dart';

// Stub — SQLite replaced by Cloud Firestore
final databaseServiceProvider =
    Provider<DatabaseService>((ref) => DatabaseService());

class DatabaseService {}