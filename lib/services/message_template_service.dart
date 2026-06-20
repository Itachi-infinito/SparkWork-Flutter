import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message_template.dart';

final messageTemplateServiceProvider =
    Provider<MessageTemplateService>((ref) => MessageTemplateService());

class MessageTemplateService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String recruiterId) =>
      _db.collection('message_templates').doc(recruiterId).collection('templates');

  /// Crée les 5 modèles par défaut au premier accès Pro (si aucun n'existe encore).
  Future<List<MessageTemplate>> ensureDefaultTemplates(String recruiterId) async {
    final existing = await getTemplates(recruiterId);
    if (existing.isNotEmpty) return existing;
    final defaults = MessageTemplate.defaults();
    final batch = _db.batch();
    for (final t in defaults) {
      batch.set(_col(recruiterId).doc(), t.toMap());
    }
    await batch.commit();
    return getTemplates(recruiterId);
  }

  Future<List<MessageTemplate>> getTemplates(String recruiterId) async {
    try {
      final q = await _col(recruiterId).orderBy('createdAt').get();
      return q.docs.map((d) => MessageTemplate.fromMap(d.data(), d.id)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveTemplate(String recruiterId, MessageTemplate template) async {
    if (template.templateId.isEmpty) {
      await _col(recruiterId).add(template.toMap());
    } else {
      await _col(recruiterId).doc(template.templateId).update(template.toMap());
    }
  }

  Future<void> deleteTemplate(String recruiterId, String templateId) async {
    await _col(recruiterId).doc(templateId).delete();
  }

  Future<void> incrementUsage(String recruiterId, String templateId) async {
    await _col(recruiterId).doc(templateId).update({
      'usageCount': FieldValue.increment(1),
    });
  }
}
