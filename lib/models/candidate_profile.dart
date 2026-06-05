import '../core/constants/app_skills.dart';

class CandidateProfile {
  final String profileId;
  final String userId;
  final String fullName;
  final String location;
  final String desiredContractType;
  final String desiredLevel;
  final List<String> skills;
  final String bio;
  final int desiredSalaryMin;
  final int desiredSalaryMax;
  final String remotePreference;
  final double latitude;
  final double longitude;
  final String? jobTitle;
  final String? photoUrl;

  const CandidateProfile({
    required this.profileId,
    required this.userId,
    required this.fullName,
    this.location = '',
    this.desiredContractType = '',
    this.desiredLevel = '',
    this.skills = const [],
    this.bio = '',
    this.desiredSalaryMin = 0,
    this.desiredSalaryMax = 0,
    this.remotePreference = '',
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.jobTitle,
    this.photoUrl,
  });

  // Alias getters pour compatibilité avec les fichiers locaux
  List<String> get skillList => skills;
  String? get locationCity => location.isEmpty ? null : location;
  String get contractType => desiredContractType;
  String? get experienceLevel => desiredLevel.isEmpty ? null : desiredLevel;
  String? get photoPath => photoUrl;

  bool get hasSalary => desiredSalaryMin > 0 || desiredSalaryMax > 0;

  String get salaryDisplay {
    if (desiredSalaryMin > 0 && desiredSalaryMax > 0) {
      return '$desiredSalaryMin - $desiredSalaryMax €';
    }
    if (desiredSalaryMin > 0) return 'À partir de $desiredSalaryMin €';
    if (desiredSalaryMax > 0) return "Jusqu'à $desiredSalaryMax €";
    return 'Salaire non renseigné';
  }

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }

  Map<String, dynamic> toMap() => {
    'profileId': profileId,
    'userId': userId,
    'fullName': fullName,
    'location': location,
    'desiredContractType': desiredContractType,
    'desiredLevel': desiredLevel,
    'skills': skills.join(', '),
    'bio': bio,
    'desiredSalaryMin': desiredSalaryMin,
    'desiredSalaryMax': desiredSalaryMax,
    'remotePreference': remotePreference,
    'latitude': latitude,
    'longitude': longitude,
    if (jobTitle != null) 'jobTitle': jobTitle,
    if (photoUrl != null) 'photoUrl': photoUrl,
  };

  factory CandidateProfile.fromMap(Map<String, dynamic> map) => CandidateProfile(
    profileId: map['profileId'] as String? ?? '',
    userId: map['userId'] as String? ?? '',
    fullName: map['fullName'] as String? ?? '',
    location: map['location'] as String? ?? '',
    desiredContractType: map['desiredContractType'] as String? ?? '',
    desiredLevel: map['desiredLevel'] as String? ?? '',
    skills: AppSkills.parseSkills(map['skills'] as String? ?? ''),
    bio: map['bio'] as String? ?? '',
    desiredSalaryMin: (map['desiredSalaryMin'] as num?)?.toInt() ?? 0,
    desiredSalaryMax: (map['desiredSalaryMax'] as num?)?.toInt() ?? 0,
    remotePreference: map['remotePreference'] as String? ?? '',
    latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
    longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
    jobTitle: map['jobTitle'] as String?,
    photoUrl: map['photoUrl'] as String?,
  );

  CandidateProfile copyWith({
    String? profileId,
    String? userId,
    String? fullName,
    String? location,
    String? desiredContractType,
    String? desiredLevel,
    List<String>? skills,
    String? bio,
    int? desiredSalaryMin,
    int? desiredSalaryMax,
    String? remotePreference,
    double? latitude,
    double? longitude,
    String? jobTitle,
    String? photoUrl,
  }) => CandidateProfile(
    profileId: profileId ?? this.profileId,
    userId: userId ?? this.userId,
    fullName: fullName ?? this.fullName,
    location: location ?? this.location,
    desiredContractType: desiredContractType ?? this.desiredContractType,
    desiredLevel: desiredLevel ?? this.desiredLevel,
    skills: skills ?? this.skills,
    bio: bio ?? this.bio,
    desiredSalaryMin: desiredSalaryMin ?? this.desiredSalaryMin,
    desiredSalaryMax: desiredSalaryMax ?? this.desiredSalaryMax,
    remotePreference: remotePreference ?? this.remotePreference,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    jobTitle: jobTitle ?? this.jobTitle,
    photoUrl: photoUrl ?? this.photoUrl,
  );
}