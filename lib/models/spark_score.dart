class SparkScoreFactor {
  final String key;
  final String label;
  final int value; // 0-100
  final double weight;
  final String explanation;

  const SparkScoreFactor({
    required this.key,
    required this.label,
    required this.value,
    required this.weight,
    required this.explanation,
  });
}

class SparkScoreResult {
  final int globalScore;
  final List<SparkScoreFactor> factors;

  const SparkScoreResult({required this.globalScore, required this.factors});

  static const _labels = {
    'skills': 'Compétences',
    'location': 'Localisation',
    'availability': 'Disponibilité',
    'salary': 'Salaire',
    'ratings': 'Notes reçues',
    'stability': 'Stabilité professionnelle',
  };

  factory SparkScoreResult.fromMap(Map<dynamic, dynamic> map) {
    final factorsMap = (map['factors'] as Map?) ?? {};
    final factors = factorsMap.entries.map((e) {
      final key = e.key as String;
      final f = e.value as Map;
      return SparkScoreFactor(
        key: key,
        label: _labels[key] ?? key,
        value: (f['value'] as num).toInt(),
        weight: (f['weight'] as num).toDouble(),
        explanation: f['explanation'] as String? ?? '',
      );
    }).toList();
    // Ordre stable d'affichage (compétences en premier, etc.)
    const order = ['skills', 'location', 'availability', 'salary', 'ratings', 'stability'];
    factors.sort((a, b) => order.indexOf(a.key).compareTo(order.indexOf(b.key)));
    return SparkScoreResult(
      globalScore: (map['globalScore'] as num).toInt(),
      factors: factors,
    );
  }
}
