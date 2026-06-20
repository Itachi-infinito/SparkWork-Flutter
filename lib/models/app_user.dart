class AppUser {
  final String uid;
  final String email;
  final String fullName;
  final String role;
  final bool isAdmin;

  const AppUser({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.role,
    this.isAdmin = false,
  });

  bool get isCandidate => role == 'candidate';
  bool get isRecruiter => role == 'recruiter';

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'fullName': fullName,
        'role': role,
        'isAdmin': isAdmin,
      };

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        uid: map['uid'] as String? ?? '',
        email: map['email'] as String? ?? '',
        fullName: map['fullName'] as String? ?? '',
        role: map['role'] as String? ?? '',
        isAdmin: map['isAdmin'] as bool? ?? false,
      );
}