import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../models/recruiter_theme.dart';
import '../../services/recruiter_theme_service.dart';

/// Personnalisation des couleurs (Pro) — l'utilisateur choisit primaire,
/// secondaire et fond ; les autres valeurs (cardColor, navigationBarColor,
/// gradient, textes) sont dérivées automatiquement pour rester cohérentes
/// et lisibles, avec un avertissement si le contraste WCAG est insuffisant.
class ThemeCustomizationPage extends ConsumerStatefulWidget {
  const ThemeCustomizationPage({super.key});

  @override
  ConsumerState<ThemeCustomizationPage> createState() => _ThemeCustomizationPageState();
}

class _ThemeCustomizationPageState extends ConsumerState<ThemeCustomizationPage> {
  late Color _primary;
  late Color _secondary;
  late Color _background;

  @override
  void initState() {
    super.initState();
    final current = ref.read(recruiterThemeProvider);
    final isCustom = current?.themeId == 'custom';
    _primary = isCustom ? current!.primaryColor : RecruiterTheme.spark.primaryColor;
    _secondary = isCustom ? current!.secondaryColor : RecruiterTheme.spark.secondaryColor;
    _background = isCustom ? current!.backgroundColor : RecruiterTheme.spark.backgroundColor;
  }

  bool get _isDark => _background.computeLuminance() < 0.5;

  Color get _textPrimary => _isDark ? const Color(0xFFF0EBF8) : const Color(0xFF1A1A1A);
  Color get _textSecondary => _textPrimary.withOpacity(0.55);
  Color get _card => _isDark
      ? Color.alphaBlend(Colors.white.withOpacity(0.06), _background)
      : Colors.white;
  Color get _navBar => _isDark
      ? Color.alphaBlend(Colors.white.withOpacity(0.03), _background)
      : Color.alphaBlend(Colors.black.withOpacity(0.03), _background);

  /// Ratio de contraste WCAG entre le texte principal et le fond.
  double get _contrastRatio {
    final l1 = _textPrimary.computeLuminance() + 0.05;
    final l2 = _background.computeLuminance() + 0.05;
    return l1 > l2 ? l1 / l2 : l2 / l1;
  }

  bool get _contrastOk => _contrastRatio >= 4.5;

  Future<void> _pickColor(String label, Color current, void Function(Color) onChanged) async {
    Color temp = current;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: temp,
            onColorChanged: (c) => temp = c,
            enableAlpha: false,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              setState(() => onChanged(temp));
              Navigator.pop(ctx);
            },
            child: const Text('Choisir'),
          ),
        ],
      ),
    );
  }

  RecruiterTheme get _customTheme => RecruiterTheme(
        themeId: 'custom',
        themeName: 'Mon thème',
        primaryColor: _primary,
        secondaryColor: _secondary,
        backgroundColor: _background,
        cardColor: _card,
        navigationBarColor: _navBar,
        gradientStart: _primary,
        gradientEnd: _secondary,
        textPrimaryColor: _textPrimary,
        textSecondaryColor: _textSecondary,
      );

  Future<void> _save() async {
    await ref.read(recruiterThemeProvider.notifier).setTheme(_customTheme);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Votre thème personnalisé a été enregistré.'),
        backgroundColor: AppColors.green,
      ));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer mon thème')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _ColorRow(label: 'Couleur primaire', color: _primary, onTap: () => _pickColor('Couleur primaire', _primary, (c) => _primary = c)),
          _ColorRow(label: 'Couleur secondaire', color: _secondary, onTap: () => _pickColor('Couleur secondaire', _secondary, (c) => _secondary = c)),
          _ColorRow(label: 'Couleur de fond', color: _background, onTap: () => _pickColor('Couleur de fond', _background, (c) => _background = c)),
          const SizedBox(height: 20),
          if (!_contrastOk)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.orange.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.orange, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Contraste insuffisant entre le texte et le fond (ratio ${_contrastRatio.toStringAsFixed(1)}:1, '
                    'recommandé ≥ 4.5:1 — norme WCAG AA). La lisibilité pourrait être affectée.',
                    style: const TextStyle(fontSize: 12, color: AppColors.orange),
                  ),
                ),
              ]),
            ),
          const SizedBox(height: 20),
          const Text('Aperçu', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _background, borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  CircleAvatar(backgroundColor: _primary, radius: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Candidat exemple', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('Serveur de salle', style: TextStyle(color: _textSecondary, fontSize: 11)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(backgroundColor: _primary),
                  child: const Text('Bouton d\'action', style: TextStyle(color: Colors.white)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Enregistrer mon thème', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorRow extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ColorRow({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade300)),
        ),
      ),
      onTap: onTap,
    );
  }
}
