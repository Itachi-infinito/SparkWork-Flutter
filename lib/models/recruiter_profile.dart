class RecruiterProfile {
  final String profileId;
  final String userId;
  final String companyName;
  final String companyDescription;
  final String location;
  final String website;
  final String sector;
  final String? contactPhotoUrl;
  final String? companyLogoUrl;

  const RecruiterProfile({
    required this.profileId,
    required this.userId,
    required this.companyName,
    this.companyDescription = '',
    this.location = '',
    this.website = '',
    this.sector = '',
    this.contactPhotoUrl,
    this.companyLogoUrl,
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
    if (contactPhotoUrl != null) 'contactPhotoUrl': contactPhotoUrl,
    if (companyLogoUrl != null) 'companyLogoUrl': companyLogoUrl,
  };

  factory RecruiterProfile.fromMap(Map<String, dynamic> map) => RecruiterProfile(
    profileId: map['profileId'] as String? ?? '',
    userId: map['userId'] as String? ?? '',
    companyName: map['companyName'] as String? ?? '',
    companyDescription: map['companyDescription'] as String? ?? '',
    location: map['location'] as String? ?? '',
    website: map['website'] as String? ?? '',
    sector: map['sector'] as String? ?? '',
    contactPhotoUrl: map['contactPhotoUrl'] as String?,
    companyLogoUrl: map['companyLogoUrl'] as String?,
  );

  RecruiterProfile copyWith({
    String? profileId,
    String? userId,
    String? companyName,
    String? companyDescription,
    String? location,
    String? website,
    String? sector,
    String? contactPhotoUrl,
    String? companyLogoUrl,
  }) => RecruiterProfile(
    profileId: profileId ?? this.profileId,
    userId: userId ?? this.userId,
    companyName: companyName ?? this.companyName,
    companyDescription: companyDescription ?? this.companyDescription,
    location: location ?? this.location,
    website: website ?? this.website,
    sector: sector ?? this.sector,
    contactPhotoUrl: contactPhotoUrl ?? this.contactPhotoUrl,
    companyLogoUrl: companyLogoUrl ?? this.companyLogoUrl,
  );
}
