class InsightReport {
  final String reportId;
  final int month;
  final int year;
  final String sector;
  final String region;
  final Map<String, double> averageSalaryByRole;
  final List<String> mostSearchedSkills;
  final int averageMatchTimeHours;
  final int totalActiveProfiles;
  final String generatedAt;

  const InsightReport({
    required this.reportId,
    required this.month,
    required this.year,
    required this.sector,
    required this.region,
    required this.averageSalaryByRole,
    required this.mostSearchedSkills,
    required this.averageMatchTimeHours,
    required this.totalActiveProfiles,
    required this.generatedAt,
  });

  String get monthLabel {
    const months = [
      '', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return month >= 1 && month <= 12 ? months[month] : '';
  }

  String get periodLabel => '$monthLabel $year';

  Map<String, dynamic> toMap() => {
        'reportId': reportId,
        'month': month,
        'year': year,
        'sector': sector,
        'region': region,
        'averageSalaryByRole': averageSalaryByRole,
        'mostSearchedSkills': mostSearchedSkills,
        'averageMatchTimeHours': averageMatchTimeHours,
        'totalActiveProfiles': totalActiveProfiles,
        'generatedAt': generatedAt,
      };

  factory InsightReport.fromMap(Map<String, dynamic> map) => InsightReport(
        reportId: map['reportId'] as String? ?? '',
        month: (map['month'] as num?)?.toInt() ?? 0,
        year: (map['year'] as num?)?.toInt() ?? 0,
        sector: map['sector'] as String? ?? '',
        region: map['region'] as String? ?? '',
        averageSalaryByRole: (map['averageSalaryByRole'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
        mostSearchedSkills: List<String>.from(map['mostSearchedSkills'] as List? ?? []),
        averageMatchTimeHours: (map['averageMatchTimeHours'] as num?)?.toInt() ?? 0,
        totalActiveProfiles: (map['totalActiveProfiles'] as num?)?.toInt() ?? 0,
        generatedAt: map['generatedAt'] as String? ?? '',
      );
}
