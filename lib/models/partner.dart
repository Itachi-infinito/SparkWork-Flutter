enum PartnerType { school, union, association }

extension PartnerTypeExt on PartnerType {
  String get label {
    switch (this) {
      case PartnerType.school: return 'École';
      case PartnerType.union: return 'Syndicat';
      case PartnerType.association: return 'Association';
    }
  }

  String get value {
    switch (this) {
      case PartnerType.school: return 'school';
      case PartnerType.union: return 'union';
      case PartnerType.association: return 'association';
    }
  }
}

class Partner {
  final String partnerId;
  final String name;
  final String type; // school / union / association
  final String contactEmail;
  final String referralCode;
  final double commissionRate;
  final int totalReferrals;
  final String createdAt;

  const Partner({
    required this.partnerId,
    required this.name,
    required this.type,
    required this.contactEmail,
    required this.referralCode,
    this.commissionRate = 0.1,
    this.totalReferrals = 0,
    required this.createdAt,
  });

  PartnerType get typeEnum {
    switch (type) {
      case 'union': return PartnerType.union;
      case 'association': return PartnerType.association;
      default: return PartnerType.school;
    }
  }

  Map<String, dynamic> toMap() => {
        'partnerId': partnerId,
        'name': name,
        'type': type,
        'contactEmail': contactEmail,
        'referralCode': referralCode,
        'commissionRate': commissionRate,
        'totalReferrals': totalReferrals,
        'createdAt': createdAt,
      };

  factory Partner.fromMap(Map<String, dynamic> map) => Partner(
        partnerId: map['partnerId'] as String? ?? '',
        name: map['name'] as String? ?? '',
        type: map['type'] as String? ?? 'school',
        contactEmail: map['contactEmail'] as String? ?? '',
        referralCode: map['referralCode'] as String? ?? '',
        commissionRate: (map['commissionRate'] as num?)?.toDouble() ?? 0.1,
        totalReferrals: (map['totalReferrals'] as num?)?.toInt() ?? 0,
        createdAt: map['createdAt'] as String? ?? '',
      );
}

class Referral {
  final String referralId;
  final String partnerId;
  final String referredUserId;
  final String referredUserType; // candidate / recruiter
  final bool convertedToPaid;
  final String? conversionDate;
  final double commissionEarned;
  final String createdAt;

  const Referral({
    required this.referralId,
    required this.partnerId,
    required this.referredUserId,
    required this.referredUserType,
    this.convertedToPaid = false,
    this.conversionDate,
    this.commissionEarned = 0.0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'referralId': referralId,
        'partnerId': partnerId,
        'referredUserId': referredUserId,
        'referredUserType': referredUserType,
        'convertedToPaid': convertedToPaid,
        if (conversionDate != null) 'conversionDate': conversionDate,
        'commissionEarned': commissionEarned,
        'createdAt': createdAt,
      };

  factory Referral.fromMap(Map<String, dynamic> map) => Referral(
        referralId: map['referralId'] as String? ?? '',
        partnerId: map['partnerId'] as String? ?? '',
        referredUserId: map['referredUserId'] as String? ?? '',
        referredUserType: map['referredUserType'] as String? ?? 'candidate',
        convertedToPaid: map['convertedToPaid'] as bool? ?? false,
        conversionDate: map['conversionDate'] as String?,
        commissionEarned: (map['commissionEarned'] as num?)?.toDouble() ?? 0.0,
        createdAt: map['createdAt'] as String? ?? '',
      );
}
