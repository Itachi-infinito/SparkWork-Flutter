import '../core/constants/app_skills.dart';

class JobOffer {
  final String jobOfferId;
  final String recruiterUserId;
  final String title;
  final String companyName;
  final String location;
  final String contractType;
  final String description;
  final String address;
  final double latitude;
  final double longitude;
  final int salaryMin;
  final int salaryMax;
  final String requiredSkills;
  final String niceToHaveSkills;
  final String remoteMode;
  final String level;
  final bool isActive;

  const JobOffer({
    required this.jobOfferId,
    required this.recruiterUserId,
    required this.title,
    required this.companyName,
    required this.location,
    required this.contractType,
    required this.description,
    this.address = '',
    this.latitude = 0.0,
    this.longitude = 0.0,
    required this.salaryMin,
    required this.salaryMax,
    required this.requiredSkills,
    required this.niceToHaveSkills,
    required this.remoteMode,
    required this.level,
    this.isActive = true,
  });

  bool get hasSalary => salaryMin > 0 || salaryMax > 0;

  String get salaryDisplay {
    if (salaryMin > 0 && salaryMax > 0) return '$salaryMin - $salaryMax €';
    if (salaryMin > 0) return 'À partir de $salaryMin €';
    if (salaryMax > 0) return "Jusqu'à $salaryMax €";
    return 'Salaire non renseigné';
  }

  String get initials {
    final parts = companyName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return companyName.isNotEmpty ? companyName[0].toUpperCase() : '?';
  }

  List<String> get requiredSkillList => AppSkills.parseSkills(requiredSkills);
  List<String> get niceSkillList => AppSkills.parseSkills(niceToHaveSkills);

  Map<String, dynamic> toMap() => {
        'jobOfferId': jobOfferId,
        'recruiterUserId': recruiterUserId,
        'title': title,
        'companyName': companyName,
        'location': location,
        'contractType': contractType,
        'description': description,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'salaryMin': salaryMin,
        'salaryMax': salaryMax,
        'requiredSkills': requiredSkills,
        'niceToHaveSkills': niceToHaveSkills,
        'remoteMode': remoteMode,
        'level': level,
        'isActive': isActive,
      };

  factory JobOffer.fromMap(Map<String, dynamic> map) => JobOffer(
        jobOfferId: map['jobOfferId'] as String? ?? '',
        recruiterUserId: map['recruiterUserId'] as String? ?? '',
        title: map['title'] as String? ?? '',
        companyName: map['companyName'] as String? ?? '',
        location: map['location'] as String? ?? '',
        contractType: map['contractType'] as String? ?? '',
        description: map['description'] as String? ?? '',
        address: map['address'] as String? ?? '',
        latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
        salaryMin: (map['salaryMin'] as num?)?.toInt() ?? 0,
        salaryMax: (map['salaryMax'] as num?)?.toInt() ?? 0,
        requiredSkills: map['requiredSkills'] as String? ?? '',
        niceToHaveSkills: map['niceToHaveSkills'] as String? ?? '',
        remoteMode: map['remoteMode'] as String? ?? '',
        level: map['level'] as String? ?? '',
        isActive: map['isActive'] as bool? ?? true,
      );

  JobOffer copyWith({
    String? jobOfferId,
    String? recruiterUserId,
    String? title,
    String? companyName,
    String? location,
    String? contractType,
    String? description,
    String? address,
    double? latitude,
    double? longitude,
    int? salaryMin,
    int? salaryMax,
    String? requiredSkills,
    String? niceToHaveSkills,
    String? remoteMode,
    String? level,
    bool? isActive,
  }) =>
      JobOffer(
        jobOfferId: jobOfferId ?? this.jobOfferId,
        recruiterUserId: recruiterUserId ?? this.recruiterUserId,
        title: title ?? this.title,
        companyName: companyName ?? this.companyName,
        location: location ?? this.location,
        contractType: contractType ?? this.contractType,
        description: description ?? this.description,
        address: address ?? this.address,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        salaryMin: salaryMin ?? this.salaryMin,
        salaryMax: salaryMax ?? this.salaryMax,
        requiredSkills: requiredSkills ?? this.requiredSkills,
        niceToHaveSkills: niceToHaveSkills ?? this.niceToHaveSkills,
        remoteMode: remoteMode ?? this.remoteMode,
        level: level ?? this.level,
        isActive: isActive ?? this.isActive,
      );
}