import '../core/constants/app_skills.dart';

enum VerificationStatus { unverified, pending, verified, rejected }

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

  // Disponible Maintenant (Feature 2)
  final bool isAvailableNow;
  final String? availableNowUntil; // ISO8601
  final String? availableNowUpdatedAt;

  // Vérification d'identité (Feature 3)
  final String verificationStatus; // unverified/pending/verified/rejected
  final String? verificationDate;
  final String? verificationMethod;
  final String? verificationRejectionReason;

  // Programme partenaires (Feature 9)
  final String? partnerBadge; // ex: "École Paul Bocuse"

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
    this.isAvailableNow = false,
    this.availableNowUntil,
    this.availableNowUpdatedAt,
    this.verificationStatus = 'unverified',
    this.verificationDate,
    this.verificationMethod,
    this.verificationRejectionReason,
    this.partnerBadge,
  });

  bool get isAvailableNowActive {
    if (!isAvailableNow || availableNowUntil == null) return false;
    try {
      return DateTime.parse(availableNowUntil!).isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  int get availableNowDaysLeft {
    if (!isAvailableNowActive) return 0;
    try {
      return DateTime.parse(availableNowUntil!).difference(DateTime.now()).inDays;
    } catch (_) {
      return 0;
    }
  }

  VerificationStatus get verificationStatusEnum {
    switch (verificationStatus) {
      case 'pending': return VerificationStatus.pending;
      case 'verified': return VerificationStatus.verified;
      case 'rejected': return VerificationStatus.rejected;
      default: return VerificationStatus.unverified;
    }
  }

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
    'isAvailableNow': isAvailableNow,
    if (availableNowUntil != null) 'availableNowUntil': availableNowUntil,
    if (availableNowUpdatedAt != null) 'availableNowUpdatedAt': availableNowUpdatedAt,
    'verificationStatus': verificationStatus,
    if (verificationDate != null) 'verificationDate': verificationDate,
    if (verificationMethod != null) 'verificationMethod': verificationMethod,
    if (verificationRejectionReason != null) 'verificationRejectionReason': verificationRejectionReason,
    if (partnerBadge != null) 'partnerBadge': partnerBadge,
  };

  factory CandidateProfile.fromMap(Map<String, dynamic> map) => CandidateProfile(
    profileId: map['profileId'] as String? ?? '',
    userId: map['userId'] as String? ?? '',
    fullName: map['fullName'] as String? ?? '',
    location: map['location'] as String? ?? '',
    desiredContractType: map['desiredContractType'] as String? ?? '',
    desiredLevel:
        AppSkills.normalizeLevel(map['desiredLevel'] as String? ?? ''),
    skills: AppSkills.parseSkills(map['skills'] as String? ?? ''),
    bio: map['bio'] as String? ?? '',
    desiredSalaryMin: (map['desiredSalaryMin'] as num?)?.toInt() ?? 0,
    desiredSalaryMax: (map['desiredSalaryMax'] as num?)?.toInt() ?? 0,
    remotePreference:
        AppSkills.normalizeRemote(map['remotePreference'] as String? ?? ''),
    latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
    longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
    jobTitle: map['jobTitle'] as String?,
    photoUrl: map['photoUrl'] as String?,
    isAvailableNow: map['isAvailableNow'] as bool? ?? false,
    availableNowUntil: map['availableNowUntil'] as String?,
    availableNowUpdatedAt: map['availableNowUpdatedAt'] as String?,
    verificationStatus: map['verificationStatus'] as String? ?? 'unverified',
    verificationDate: map['verificationDate'] as String?,
    verificationMethod: map['verificationMethod'] as String?,
    verificationRejectionReason: map['verificationRejectionReason'] as String?,
    partnerBadge: map['partnerBadge'] as String?,
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
    bool? isAvailableNow,
    String? availableNowUntil,
    String? availableNowUpdatedAt,
    String? verificationStatus,
    String? verificationDate,
    String? verificationMethod,
    String? verificationRejectionReason,
    String? partnerBadge,
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
    isAvailableNow: isAvailableNow ?? this.isAvailableNow,
    availableNowUntil: availableNowUntil ?? this.availableNowUntil,
    availableNowUpdatedAt: availableNowUpdatedAt ?? this.availableNowUpdatedAt,
    verificationStatus: verificationStatus ?? this.verificationStatus,
    verificationDate: verificationDate ?? this.verificationDate,
    verificationMethod: verificationMethod ?? this.verificationMethod,
    verificationRejectionReason: verificationRejectionReason ?? this.verificationRejectionReason,
    partnerBadge: partnerBadge ?? this.partnerBadge,
  );
}