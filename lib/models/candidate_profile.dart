class CandidateProfile {
  final int profileId;
  final int userId;
  final String fullName;
  final String email;
  final String bio;
  final String skills;
  final String desiredContractType;
  final String experienceLevel;
  final int desiredSalaryMin;
  final int desiredSalaryMax;
  final int maxDistanceKm;
  final double latitude;
  final double longitude;
  final String experienceTitle1;
  final String experienceCompany1;
  final String experiencePeriod1;
  final String experienceTitle2;
  final String experienceCompany2;
  final String experiencePeriod2;

  CandidateProfile({
    this.profileId = 0, required this.userId, required this.fullName,
    required this.email, this.bio = '', this.skills = '',
    this.desiredContractType = '', this.experienceLevel = '',
    this.desiredSalaryMin = 0, this.desiredSalaryMax = 0,
    this.maxDistanceKm = 25, this.latitude = 0, this.longitude = 0,
    this.experienceTitle1 = '', this.experienceCompany1 = '', this.experiencePeriod1 = '',
    this.experienceTitle2 = '', this.experienceCompany2 = '', this.experiencePeriod2 = '',
  });

  List<String> get skillList =>
      skills.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  Map<String, dynamic> toMap() => {
    'profileId': profileId == 0 ? null : profileId,
    'userId': userId, 'fullName': fullName, 'email': email,
    'bio': bio, 'skills': skills, 'desiredContractType': desiredContractType,
    'experienceLevel': experienceLevel, 'desiredSalaryMin': desiredSalaryMin,
    'desiredSalaryMax': desiredSalaryMax, 'maxDistanceKm': maxDistanceKm,
    'latitude': latitude, 'longitude': longitude,
    'experienceTitle1': experienceTitle1, 'experienceCompany1': experienceCompany1,
    'experiencePeriod1': experiencePeriod1, 'experienceTitle2': experienceTitle2,
    'experienceCompany2': experienceCompany2, 'experiencePeriod2': experiencePeriod2,
  };

  factory CandidateProfile.fromMap(Map<String, dynamic> m) => CandidateProfile(
    profileId: m['profileId'] as int? ?? 0,
    userId: m['userId'] as int, fullName: m['fullName'] as String,
    email: m['email'] as String, bio: m['bio'] as String? ?? '',
    skills: m['skills'] as String? ?? '',
    desiredContractType: m['desiredContractType'] as String? ?? '',
    experienceLevel: m['experienceLevel'] as String? ?? '',
    desiredSalaryMin: m['desiredSalaryMin'] as int? ?? 0,
    desiredSalaryMax: m['desiredSalaryMax'] as int? ?? 0,
    maxDistanceKm: m['maxDistanceKm'] as int? ?? 25,
    latitude: (m['latitude'] as num?)?.toDouble() ?? 0,
    longitude: (m['longitude'] as num?)?.toDouble() ?? 0,
    experienceTitle1: m['experienceTitle1'] as String? ?? '',
    experienceCompany1: m['experienceCompany1'] as String? ?? '',
    experiencePeriod1: m['experiencePeriod1'] as String? ?? '',
    experienceTitle2: m['experienceTitle2'] as String? ?? '',
    experienceCompany2: m['experienceCompany2'] as String? ?? '',
    experiencePeriod2: m['experiencePeriod2'] as String? ?? '',
  );
}
