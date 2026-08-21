class WorkExperience {
  final String jobTitle;
  final String company;
  final String startDate; // "yyyy-MM"
  final String? endDate;  // "yyyy-MM", null si poste actuel
  final bool isCurrent;

  const WorkExperience({
    required this.jobTitle,
    required this.company,
    required this.startDate,
    this.endDate,
    this.isCurrent = false,
  });

  int get tenureMonths {
    final start = _parse(startDate);
    final end = (isCurrent || endDate == null) ? DateTime.now() : _parse(endDate!);
    return ((end.year - start.year) * 12 + (end.month - start.month)).clamp(0, 9999);
  }

  String get durationLabel {
    final m = tenureMonths;
    if (m < 12) return '${m} mois';
    final y = m ~/ 12;
    final r = m % 12;
    return r > 0 ? '$y an${y > 1 ? 's' : ''} $r mois' : '$y an${y > 1 ? 's' : ''}';
  }

  String get periodLabel {
    final start = _formatYM(startDate);
    final end = isCurrent ? 'Aujourd\'hui' : (endDate != null ? _formatYM(endDate!) : '?');
    return '$start – $end';
  }

  static DateTime _parse(String ym) {
    final parts = ym.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]));
  }

  static String _formatYM(String ym) {
    final parts = ym.split('-');
    const months = ['', 'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun',
                    'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
    final m = int.tryParse(parts[1]) ?? 1;
    return '${months[m.clamp(1, 12)]} ${parts[0]}';
  }

  Map<String, dynamic> toMap() => {
    'jobTitle': jobTitle,
    'company': company,
    'startDate': startDate,
    if (endDate != null) 'endDate': endDate,
    'isCurrent': isCurrent,
  };

  factory WorkExperience.fromMap(Map<String, dynamic> map) => WorkExperience(
    jobTitle: map['jobTitle'] as String? ?? '',
    company: map['company'] as String? ?? '',
    startDate: map['startDate'] as String? ?? '',
    endDate: map['endDate'] as String?,
    isCurrent: map['isCurrent'] as bool? ?? false,
  );

  WorkExperience copyWith({
    String? jobTitle,
    String? company,
    String? startDate,
    String? endDate,
    bool? isCurrent,
  }) => WorkExperience(
    jobTitle: jobTitle ?? this.jobTitle,
    company: company ?? this.company,
    startDate: startDate ?? this.startDate,
    endDate: isCurrent == true ? null : (endDate ?? this.endDate),
    isCurrent: isCurrent ?? this.isCurrent,
  );
}
