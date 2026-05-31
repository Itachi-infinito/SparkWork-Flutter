import '../core/constants/app_skills.dart';

class CandidateProfile {
  final int profileId;
  final int userId;
  final String fullName;
  final String location;
  final String desiredContractType;
  final String desiredLevel;
  final String skills;
  final String bio;
  final int desiredSalaryMin;
  final int desiredSalaryMax;
  final String remotePreference;
  final double latitude;
  final double longitude;
  final String? photoPath;

  const CandidateProfile({
    required this.profileId,
    required this.userId,
    required this.fullName,
    required this.location,
    required this.desiredContractType,
    required this.desiredLevel,
    required this.skills,
    required this.bio,
    required this.desiredSalaryMin,
    required this.desiredSalaryMax,
    required this.remotePreference,
    required this.latitude,
    required this.longitude,
    this.photoPath,
  });

  List<String> get skillList => AppSkills.parseSkills(skills);
  bool get hasSalary => desiredSalaryMin > 0 || desiredSalaryMax > 0;

  String get salaryDisplay {
    if (desiredSalaryMin > 0 && desiredSalaryMax > 0) return '$desiredSalaryMin - $desiredSalaryMax €';
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
    'skills': skills,
    'bio': bio,
    'desiredSalaryMin': desiredSalaryMin,
    'desiredSalaryMax': desiredSalaryMax,
    'remotePreference': remotePreference,
    'latitude': latitude,
    'longitude': longitude,
    'photoPath': photoPath,
  };

  factory CandidateProfile.fromMap(Map<String, dynamic> map) => CandidateProfile(
    profileId: map['profileId'] as int,
    userId: map['userId'] as int,
    fullName: map['fullName'] as String,
    location: map['location'] as String,
    desiredContractType: map['desiredContractType'] as String,
    desiredLevel: map['desiredLevel'] as String,
    skills: map['skills'] as String,
    bio: map['bio'] as String,
    desiredSalaryMin: map['desiredSalaryMin'] as int,
    desiredSalaryMax: map['desiredSalaryMax'] as int,
    remotePreference: map['remotePreference'] as String,
    latitude: (map['latitude'] as num).toDouble(),
    longitude: (map['longitude'] as num).toDouble(),
    photoPath: map['photoPath'] as String?,
  );

  CandidateProfile copyWith({
    int? profileId,
    int? userId,
    String? fullName,
    String? location,
    String? desiredContractType,
    String? desiredLevel,
    String? skills,
    String? bio,
    int? desiredSalaryMin,
    int? desiredSalaryMax,
    String? remotePreference,
    double? latitude,
    double? longitude,
    String? photoPath,
  }) =>
      CandidateProfile(
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
        photoPath: photoPath ?? this.photoPath,
      );
}