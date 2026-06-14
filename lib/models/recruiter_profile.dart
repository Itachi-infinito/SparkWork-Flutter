class RecruiterProfile {
  final String profileId;
  final String userId;
  final String companyName;
  final String companyDescription;
  final String location;
  final String website;
  final String sector;
  final String companyNumber; // numéro BCE/TVA belge validé à l'inscription
  final String? contactPhotoUrl;
  final String? companyLogoUrl;
  final bool isVerifiedEmployer; // true = plan Pro actif

  const RecruiterProfile({
    required this.profileId,
    required this.userId,
    required this.companyName,
    this.companyDescription = '',
    this.location = '',
    this.website = '',
    this.sector = '',
    this.companyNumber = '',
    this.contactPhotoUrl,
    this.companyLogoUrl,
    this.isVerifiedEmployer = false,
  });

  String get initials {
    final parts = companyName.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return companyName.isNotEmpty ? companyName[0].toUpperCase() : 'R';
  }

  Map<String, dynamic> toMap() => {
    'profileId': profileId,
    'userId': userId,
    'companyName': companyName,
    'companyDescription': companyDescription,
    'location': location,
    'website': website,
    'sector': sector,
    'companyNumber': companyNumber,
    if (contactPhotoUrl != null) 'contactPhotoUrl': contactPhotoUrl,
    if (companyLogoUrl != null) 'companyLogoUrl': companyLogoUrl,
    'isVerifiedEmployer': isVerifiedEmployer,
  };

  factory RecruiterProfile.fromMap(Map<String, dynamic> map) => RecruiterProfile(
    profileId: map['profileId'] as String? ?? '',
    userId: map['userId'] as String? ?? '',
    companyName: map['companyName'] as String? ?? '',
    companyDescription: map['companyDescription'] as String? ?? '',
    location: map['location'] as String? ?? '',
    website: map['website'] as String? ?? '',
    sector: map['sector'] as String? ?? '',
    companyNumber: map['companyNumber'] as String? ?? '',
    contactPhotoUrl: map['contactPhotoUrl'] as String?,
    companyLogoUrl: map['companyLogoUrl'] as String?,
    isVerifiedEmployer: map['isVerifiedEmployer'] as bool? ?? false,
  );

  RecruiterProfile copyWith({
    String? profileId,
    String? userId,
    String? companyName,
    String? companyDescription,
    String? location,
    String? website,
    String? sector,
    String? companyNumber,
    String? contactPhotoUrl,
    String? companyLogoUrl,
    bool? isVerifiedEmployer,
  }) => RecruiterProfile(
    profileId: profileId ?? this.profileId,
    userId: userId ?? this.userId,
    companyName: companyName ?? this.companyName,
    companyDescription: companyDescription ?? this.companyDescription,
    location: location ?? this.location,
    website: website ?? this.website,
    sector: sector ?? this.sector,
    companyNumber: companyNumber ?? this.companyNumber,
    contactPhotoUrl: contactPhotoUrl ?? this.contactPhotoUrl,
    companyLogoUrl: companyLogoUrl ?? this.companyLogoUrl,
    isVerifiedEmployer: isVerifiedEmployer ?? this.isVerifiedEmployer,
  );
}
