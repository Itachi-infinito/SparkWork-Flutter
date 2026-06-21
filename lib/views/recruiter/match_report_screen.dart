import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_avatar.dart';

/// Fiche de candidature synthétique générée automatiquement à la création
/// du match (Pro uniquement). Exportable en PDF pour archivage/partage.
class MatchReportScreen extends StatefulWidget {
  final String matchId;
  const MatchReportScreen({super.key, required this.matchId});

  @override
  State<MatchReportScreen> createState() => _MatchReportScreenState();
}

class _MatchReportScreenState extends State<MatchReportScreen> {
  Map<String, dynamic>? _report;
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doc = await FirebaseFirestore.instance
        .collection('match_reports')
        .doc(widget.matchId)
        .get();
    if (mounted) setState(() { _report = doc.data(); _loading = false; });
  }

  Future<void> _exportPdf() async {
    final r = _report;
    if (r == null) return;
    setState(() => _exporting = true);
    try {
      final matchingSkills = (r['matchingSkills'] as List?)?.cast<String>() ?? [];
      final otherSkills = (r['otherSkills'] as List?)?.cast<String>() ?? [];
      final sparkScore = r['sparkScore'] as int? ?? 0;
      final verificationStatus = r['verificationStatus'] as String? ?? 'unverified';
      final candidateName = r['candidateName'] as String? ?? '';

      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('SparkWork — Rapport de candidature',
                    style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                pw.SizedBox(height: 12),
                pw.Text(candidateName,
                    style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                if ((r['jobTitle'] as String? ?? '').isNotEmpty)
                  pw.Text(r['jobTitle'] as String,
                      style: const pw.TextStyle(fontSize: 13, color: PdfColors.grey700)),
                pw.SizedBox(height: 20),
                pw.Row(children: [
                  _pdfStat('SparkScore', '$sparkScore%'),
                  pw.SizedBox(width: 16),
                  _pdfStat('Note moyenne', r['averageRating'] != null
                      ? '${(r['averageRating'] as num).toStringAsFixed(1)}/5 (${r['totalReviews']})'
                      : 'Aucune'),
                ]),
                pw.SizedBox(height: 10),
                pw.Row(children: [
                  _pdfStat('Vérification', verificationStatus == 'verified' ? 'Vérifié' : 'Non vérifié'),
                  pw.SizedBox(width: 16),
                  _pdfStat('Recommandations', '${r['recommendationCount'] ?? 0}'),
                ]),
                pw.SizedBox(height: 10),
                _pdfStat('Disponibilité', r['isAvailableNow'] == true ? 'Disponible maintenant' : 'À confirmer'),
                pw.SizedBox(height: 24),
                if (matchingSkills.isNotEmpty) ...[
                  pw.Text('Compétences clés (correspondent à l\'offre)',
                      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 6),
                  pw.Wrap(spacing: 6, runSpacing: 6, children: matchingSkills
                      .map((s) => _pdfTag(s, PdfColors.green100, PdfColors.green800))
                      .toList()),
                  pw.SizedBox(height: 16),
                ],
                if (otherSkills.isNotEmpty) ...[
                  pw.Text('Autres compétences',
                      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 6),
                  pw.Wrap(spacing: 6, runSpacing: 6, children: otherSkills
                      .map((s) => _pdfTag(s, PdfColors.grey200, PdfColors.grey800))
                      .toList()),
                ],
                pw.Spacer(),
                pw.Divider(color: PdfColors.grey300),
                pw.Text(
                  'Généré automatiquement par SparkWork — usage interne au recrutement.',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
                ),
              ],
            ),
          ),
        ),
      );

      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: 'rapport_${candidateName.replaceAll(' ', '_')}.pdf',
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  pw.Widget _pdfStat(String label, String value) => pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            pw.SizedBox(height: 2),
            pw.Text(value, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          ]),
        ),
      );

  pw.Widget _pdfTag(String text, PdfColor bg, PdfColor fg) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: pw.BoxDecoration(color: bg, borderRadius: pw.BorderRadius.circular(12)),
        child: pw.Text(text, style: pw.TextStyle(fontSize: 10, color: fg)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapport de candidature'),
        actions: [
          if (_report != null)
            IconButton(
              icon: _exporting
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.picture_as_pdf_outlined),
              onPressed: _exporting ? null : _exportPdf,
              tooltip: 'Exporter en PDF',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _report == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Rapport non disponible — cette fonctionnalité est réservée au plan Pro.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _buildBody(_report!),
    );
  }

  Widget _buildBody(Map<String, dynamic> r) {
    final matchingSkills = (r['matchingSkills'] as List?)?.cast<String>() ?? [];
    final otherSkills = (r['otherSkills'] as List?)?.cast<String>() ?? [];
    final sparkScore = r['sparkScore'] as int? ?? 0;
    final verificationStatus = r['verificationStatus'] as String? ?? 'unverified';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Column(children: [
            AppAvatar(
                name: r['candidateName'] as String? ?? '?',
                radius: 44,
                photoPath: r['candidatePhotoUrl'] as String?),
            const SizedBox(height: 12),
            Text(r['candidateName'] as String? ?? '',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            if ((r['jobTitle'] as String? ?? '').isNotEmpty)
              Text(r['jobTitle'] as String,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: _StatChip(
              icon: Icons.bolt, label: 'SparkScore', value: '$sparkScore%',
              color: sparkScore > 75 ? AppColors.green : sparkScore >= 50 ? AppColors.orange : AppColors.red)),
          const SizedBox(width: 10),
          Expanded(child: _StatChip(
              icon: Icons.star, label: 'Note moyenne',
              value: r['averageRating'] != null
                  ? '${(r['averageRating'] as num).toStringAsFixed(1)}/5 (${r['totalReviews']})'
                  : 'Aucune',
              color: Colors.amber)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _StatChip(
              icon: verificationStatus == 'verified' ? Icons.verified_user : Icons.gpp_maybe_outlined,
              label: 'Vérification',
              value: verificationStatus == 'verified' ? 'Vérifié' : 'Non vérifié',
              color: verificationStatus == 'verified' ? const Color(0xFF3B82F6) : Colors.grey)),
          const SizedBox(width: 10),
          Expanded(child: _StatChip(
              icon: Icons.star_outline,
              label: 'Recommandations',
              value: '${r['recommendationCount'] ?? 0}',
              color: Colors.amber.shade700)),
        ]),
        const SizedBox(height: 10),
        _StatChip(
            icon: r['isAvailableNow'] == true ? Icons.flash_on : Icons.schedule,
            label: 'Disponibilité',
            value: r['isAvailableNow'] == true ? 'Disponible maintenant' : 'À confirmer',
            color: r['isAvailableNow'] == true ? AppColors.green : Colors.grey,
            fullWidth: true),
        const SizedBox(height: 24),
        if (matchingSkills.isNotEmpty) ...[
          const Text('Compétences clés (correspondent à l\'offre)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: matchingSkills.map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: AppColors.greenLight, borderRadius: BorderRadius.circular(20)),
                child: Text(s, style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w600, fontSize: 12)),
              )).toList()),
          const SizedBox(height: 16),
        ],
        if (otherSkills.isNotEmpty) ...[
          const Text('Autres compétences', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: otherSkills.map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
                child: Text(s, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
              )).toList()),
        ],
        const SizedBox(height: 24),
        Center(
          child: OutlinedButton.icon(
            onPressed: _exporting ? null : _exportPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: const Text('Exporter en PDF'),
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool fullWidth;
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
              Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ]),
    );
  }
}
