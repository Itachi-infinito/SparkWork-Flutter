import 'package:flutter_test/flutter_test.dart';
import 'package:sparkwork/models/recruiter_theme.dart';

void main() {
  group('RecruiterTheme presets', () {
    test('il y a exactement 5 thèmes prédéfinis', () {
      expect(RecruiterTheme.presets.length, 5);
    });

    test('byId retrouve chaque thème par son identifiant', () {
      for (final t in RecruiterTheme.presets) {
        expect(RecruiterTheme.byId(t.themeId).themeId, t.themeId);
      }
    });

    test('byId retombe sur Spark pour un identifiant inconnu', () {
      expect(RecruiterTheme.byId('inexistant').themeId, 'spark');
    });

    test('Alpine et Terracotta sont des ambiances claires', () {
      expect(RecruiterTheme.alpine.isDarkStyle, isFalse);
      expect(RecruiterTheme.terracotta.isDarkStyle, isFalse);
    });

    test('Spark, Midnight et Emerald sont des ambiances sombres', () {
      expect(RecruiterTheme.spark.isDarkStyle, isTrue);
      expect(RecruiterTheme.midnight.isDarkStyle, isTrue);
      expect(RecruiterTheme.emerald.isDarkStyle, isTrue);
    });
  });

  group('RecruiterTheme toMap/fromMap', () {
    test('un thème prédéfini fait un aller-retour fidèle', () {
      final map = RecruiterTheme.midnight.toMap();
      final restored = RecruiterTheme.fromMap(map);

      expect(restored.themeId, RecruiterTheme.midnight.themeId);
      expect(restored.primaryColor, RecruiterTheme.midnight.primaryColor);
      expect(restored.backgroundColor, RecruiterTheme.midnight.backgroundColor);
      expect(restored.isDarkStyle, RecruiterTheme.midnight.isDarkStyle);
    });

    test('fromMap retombe sur Spark si la map est vide', () {
      final restored = RecruiterTheme.fromMap({});
      expect(restored.themeId, 'spark');
    });
  });
}
