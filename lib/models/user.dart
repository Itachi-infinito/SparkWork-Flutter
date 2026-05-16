class User {
  final int userId;
  final String fullName;
  final String email;
  final String passwordHash;
  final String role; // 'candidate' or 'recruiter'

  const User({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.passwordHash,
    required this.role,
  });

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'fullName': fullName,
        'email': email,
        'passwordHash': passwordHash,
        'role': role,
      };

  factory User.fromMap(Map<String, dynamic> map) => User(
        userId: map['userId'] as int,
        fullName: map['fullName'] as String,
        email: map['email'] as String,
        passwordHash: map['passwordHash'] as String,
        role: map['role'] as String,
      );
}