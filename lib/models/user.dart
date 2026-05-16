import 'package:sqflite/sqflite.dart';

class User {
  final int userId;
  final String fullName;
  final String email;
  final String passwordHash;
  final String role;

  User({this.userId = 0, required this.fullName, required this.email, required this.passwordHash, required this.role});

  Map<String, dynamic> toMap() => {
    'userId': userId == 0 ? null : userId,
    'fullName': fullName, 'email': email,
    'passwordHash': passwordHash, 'role': role,
  };

  factory User.fromMap(Map<String, dynamic> m) => User(
    userId: m['userId'] as int,
    fullName: m['fullName'] as String,
    email: m['email'] as String,
    passwordHash: m['passwordHash'] as String,
    role: m['role'] as String,
  );
}
