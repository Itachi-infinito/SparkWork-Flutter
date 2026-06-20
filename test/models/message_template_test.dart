import 'package:flutter_test/flutter_test.dart';
import 'package:sparkwork/models/message_template.dart';

void main() {
  group('MessageTemplate.defaults', () {
    test('fournit exactement les 5 modèles spécifiés', () {
      final titles = MessageTemplate.defaults().map((t) => t.title).toList();
      expect(titles, [
        'Premier contact',
        'Invitation à un entretien',
        'Refus poli',
        'Offre formelle',
        'Demande d\'informations complémentaires',
      ]);
    });

    test('chaque modèle contient le placeholder {prénom_candidat}', () {
      for (final t in MessageTemplate.defaults()) {
        expect(t.body.contains('{prénom_candidat}'), isTrue, reason: t.title);
      }
    });
  });

  group('MessageTemplate.toMap/fromMap', () {
    test('conserve les données', () {
      const template = MessageTemplate(
        templateId: 't1',
        title: 'Test',
        body: 'Bonjour {prénom_candidat}',
        createdAt: '2026-01-01T00:00:00.000',
        usageCount: 3,
      );
      final restored = MessageTemplate.fromMap(template.toMap(), 't1');

      expect(restored.title, template.title);
      expect(restored.body, template.body);
      expect(restored.usageCount, 3);
    });

    test('fromMap retombe sur des valeurs par défaut si champs manquants', () {
      final template = MessageTemplate.fromMap({}, 'docId');
      expect(template.templateId, 'docId');
      expect(template.title, '');
      expect(template.usageCount, 0);
    });
  });
}
