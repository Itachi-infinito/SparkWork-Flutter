import 'package:flutter/material.dart';

/// Ambiance visuelle d'un recruiter — distincte du toggle clair/sombre
/// (qui reste disponible pour tout le monde, candidats compris). Le logo
/// SparkWork ne change JAMAIS quel que soit le thème choisi. Le thème d'un
/// recruteur ne s'applique qu'à SA propre interface — les candidats voient
/// toujours leurs propres écrans dans le thème Spark par défaut, peu
/// importe quel recruteur a publié l'offre qu'ils consultent.
class RecruiterTheme {
  final String themeId;
  final String themeName;
  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;
  final Color cardColor;
  final Color navigationBarColor;
  final Color gradientStart;
  final Color gradientEnd;
  final Color textPrimaryColor;
  final Color textSecondaryColor;

  const RecruiterTheme({
    required this.themeId,
    required this.themeName,
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
    required this.cardColor,
    required this.navigationBarColor,
    required this.gradientStart,
    required this.gradientEnd,
    required this.textPrimaryColor,
    required this.textSecondaryColor,
  });

  Color get badgeColor => primaryColor;

  /// Alpine et Terracotta sont des ambiances claires (fond blanc/clair) ;
  /// Spark, Midnight et Emerald sont sombres. Cette valeur pilote quel
  /// ThemeData (clair ou sombre) doit réellement être actif quand cette
  /// ambiance est sélectionnée — sinon les widgets qui se basent sur
  /// Theme.of(context).brightness (texte clair/sombre) se désynchronisent
  /// du fond réel et deviennent illisibles.
  bool get isDarkStyle => backgroundColor.computeLuminance() < 0.5;

  Map<String, dynamic> toMap() => {
        'themeId': themeId,
        'themeName': themeName,
        'primaryColor': primaryColor.toARGB32(),
        'secondaryColor': secondaryColor.toARGB32(),
        'backgroundColor': backgroundColor.toARGB32(),
        'cardColor': cardColor.toARGB32(),
        'navigationBarColor': navigationBarColor.toARGB32(),
        'gradientStart': gradientStart.toARGB32(),
        'gradientEnd': gradientEnd.toARGB32(),
        'textPrimaryColor': textPrimaryColor.toARGB32(),
        'textSecondaryColor': textSecondaryColor.toARGB32(),
      };

  factory RecruiterTheme.fromMap(Map<String, dynamic> map) => RecruiterTheme(
        themeId: map['themeId'] as String? ?? spark.themeId,
        themeName: map['themeName'] as String? ?? spark.themeName,
        primaryColor: Color(map['primaryColor'] as int? ?? spark.primaryColor.toARGB32()),
        secondaryColor: Color(map['secondaryColor'] as int? ?? spark.secondaryColor.toARGB32()),
        backgroundColor: Color(map['backgroundColor'] as int? ?? spark.backgroundColor.toARGB32()),
        cardColor: Color(map['cardColor'] as int? ?? spark.cardColor.toARGB32()),
        navigationBarColor: Color(map['navigationBarColor'] as int? ?? spark.navigationBarColor.toARGB32()),
        gradientStart: Color(map['gradientStart'] as int? ?? spark.gradientStart.toARGB32()),
        gradientEnd: Color(map['gradientEnd'] as int? ?? spark.gradientEnd.toARGB32()),
        textPrimaryColor: Color(map['textPrimaryColor'] as int? ?? spark.textPrimaryColor.toARGB32()),
        textSecondaryColor: Color(map['textSecondaryColor'] as int? ?? spark.textSecondaryColor.toARGB32()),
      );

  // ── Thèmes prédéfinis — valeurs exactes du brief ────────────────────────

  static const spark = RecruiterTheme(
    themeId: 'spark',
    themeName: 'Spark',
    primaryColor: Color(0xFF7C3AED),
    secondaryColor: Color(0xFFEC4899),
    backgroundColor: Color(0xFF0A0812),
    cardColor: Color(0xFF1A1529),
    navigationBarColor: Color(0xFF110E1C),
    gradientStart: Color(0xFF7C3AED),
    gradientEnd: Color(0xFFEC4899),
    textPrimaryColor: Color(0xFFF0EBF8),
    textSecondaryColor: Color(0x8CF0EBF8), // rgba(240,235,248,0.55)
  );

  static const midnight = RecruiterTheme(
    themeId: 'midnight',
    themeName: 'Midnight',
    primaryColor: Color(0xFFC9A84C),
    secondaryColor: Color(0xFFE8D5A3),
    backgroundColor: Color(0xFF0A0A0A),
    cardColor: Color(0xFF141414),
    navigationBarColor: Color(0xFF0F0F0F),
    gradientStart: Color(0xFFC9A84C),
    gradientEnd: Color(0xFF8B6914),
    textPrimaryColor: Color(0xFFF5F0E8),
    textSecondaryColor: Color(0x8CF5F0E8),
  );

  static const alpine = RecruiterTheme(
    themeId: 'alpine',
    themeName: 'Alpine',
    primaryColor: Color(0xFF1B3A5C),
    secondaryColor: Color(0xFF2E6DA4),
    backgroundColor: Color(0xFFF8FAFB),
    cardColor: Color(0xFFFFFFFF),
    navigationBarColor: Color(0xFFF0F4F7),
    gradientStart: Color(0xFF1B3A5C),
    gradientEnd: Color(0xFF2E6DA4),
    textPrimaryColor: Color(0xFF1A2332),
    textSecondaryColor: Color(0x8C1A2332),
  );

  static const terracotta = RecruiterTheme(
    themeId: 'terracotta',
    themeName: 'Terracotta',
    primaryColor: Color(0xFFC4622D),
    secondaryColor: Color(0xFFE8956D),
    backgroundColor: Color(0xFFFBF7F4),
    cardColor: Color(0xFFFFFFFF),
    navigationBarColor: Color(0xFFF5EDE6),
    gradientStart: Color(0xFFC4622D),
    gradientEnd: Color(0xFF8B3A1A),
    textPrimaryColor: Color(0xFF2C1810),
    textSecondaryColor: Color(0x8C2C1810),
  );

  static const emerald = RecruiterTheme(
    themeId: 'emerald',
    themeName: 'Emerald',
    primaryColor: Color(0xFF1A4A3A),
    secondaryColor: Color(0xFFC9B96E),
    backgroundColor: Color(0xFF0D1F1A),
    cardColor: Color(0xFF152B24),
    navigationBarColor: Color(0xFF111E1A),
    gradientStart: Color(0xFF1A4A3A),
    gradientEnd: Color(0xFF0D2B20),
    textPrimaryColor: Color(0xFFE8F0EC),
    textSecondaryColor: Color(0x8CE8F0EC),
  );

  static const presets = [spark, midnight, alpine, terracotta, emerald];

  static RecruiterTheme byId(String id) =>
      presets.firstWhere((t) => t.themeId == id, orElse: () => spark);
}
