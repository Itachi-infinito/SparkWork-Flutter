class JobOffer {
  final int jobOfferId;
  final int recruiterUserId;
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

  JobOffer({
    this.jobOfferId = 0, required this.recruiterUserId, required this.title,
    required this.companyName, this.location = '', this.contractType = '',
    this.description = '', this.address = '', this.latitude = 0, this.longitude = 0,
    this.salaryMin = 0, this.salaryMax = 0, this.requiredSkills = '',
    this.niceToHaveSkills = '', this.remoteMode = '', this.level = '',
  });

  bool get hasSalary => salaryMin > 0 || salaryMax > 0;

  String get salaryDisplay {
    if (salaryMin > 0 && salaryMax > 0) return ' -  €';
    if (salaryMin > 0) return 'À partir de  €';
    if (salaryMax > 0) return "Jusqu'à  €";
    return 'Salaire non renseigné';
  }

  List<String> get requiredSkillList =>
      requiredSkills.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  List<String> get niceSkillList =>
      niceToHaveSkills.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  String get initials {
    final parts = companyName.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return ''.toUpperCase();
  }

  Map<String, dynamic> toMap() => {
    'jobOfferId': jobOfferId == 0 ? null : jobOfferId,
    'recruiterUserId': recruiterUserId, 'title': title,
    'companyName': companyName, 'location': location,
    'contractType': contractType, 'description': description,
    'address': address, 'latitude': latitude, 'longitude': longitude,
    'salaryMin': salaryMin, 'salaryMax': salaryMax,
    'requiredSkills': requiredSkills, 'niceToHaveSkills': niceToHaveSkills,
    'remoteMode': remoteMode, 'level': level,
  };

  factory JobOffer.fromMap(Map<String, dynamic> m) => JobOffer(
    jobOfferId: m['jobOfferId'] as int? ?? 0,
    recruiterUserId: m['recruiterUserId'] as int,
    title: m['title'] as String,
    companyName: m['companyName'] as String,
    location: m['location'] as String? ?? '',
    contractType: m['contractType'] as String? ?? '',
    description: m['description'] as String? ?? '',
    address: m['address'] as String? ?? '',
    latitude: (m['latitude'] as num?)?.toDouble() ?? 0,
    longitude: (m['longitude'] as num?)?.toDouble() ?? 0,
    salaryMin: m['salaryMin'] as int? ?? 0,
    salaryMax: m['salaryMax'] as int? ?? 0,
    requiredSkills: m['requiredSkills'] as String? ?? '',
    niceToHaveSkills: m['niceToHaveSkills'] as String? ?? '',
    remoteMode: m['remoteMode'] as String? ?? '',
    level: m['level'] as String? ?? '',
  );
}
