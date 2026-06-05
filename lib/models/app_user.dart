class AppUser {
  final String uid;
  final String email;
  final String fullName;
  final String role;

  const AppUser({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.role,
  });

  bool get isCandidate => role == 'candidate';
  bool get isRecruiter => role == 'recruiter';

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'fullName': fullName,
        'role': role,
      };

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        uid: map['uid'] as String? ?? '',
        email: map['email'] as String? ?? '',
        fullName: map['fullName'] as String? ?? '',
        role: map['role'] as String? ?? '',
      );
}