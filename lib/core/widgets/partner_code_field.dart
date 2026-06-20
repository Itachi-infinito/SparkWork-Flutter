import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/partner.dart';
import '../../services/partner_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_theme_ext.dart';

/// Champ "Code partenaire (optionnel)" réutilisé sur les écrans d'inscription
/// candidat et recruteur. Valide le code en temps réel (debounce) contre la
/// collection `partners` et notifie le parent du résultat via [onResolved] —
/// un code invalide n'empêche jamais la suite de l'inscription.
class PartnerCodeField extends ConsumerStatefulWidget {
  final ValueChanged<Partner?> onResolved;
  const PartnerCodeField({super.key, required this.onResolved});

  @override
  ConsumerState<PartnerCodeField> createState() => _PartnerCodeFieldState();
}

class _PartnerCodeFieldState extends ConsumerState<PartnerCodeField> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  bool _checking = false;
  Partner? _resolved;
  bool _notFound = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final code = value.trim();
    if (code.isEmpty) {
      setState(() { _checking = false; _resolved = null; _notFound = false; });
      widget.onResolved(null);
      return;
    }
    setState(() { _checking = true; _notFound = false; });
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      final partner = await ref.read(partnerServiceProvider).validateCode(code);
      if (!mounted) return;
      setState(() {
        _checking = false;
        _resolved = partner;
        _notFound = partner == null;
      });
      widget.onResolved(partner);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _ctrl,
          textCapitalization: TextCapitalization.characters,
          onChanged: _onChanged,
          decoration: InputDecoration(
            labelText: 'Code partenaire (optionnel)',
            prefixIcon: const Icon(Icons.card_giftcard_outlined),
            suffixIcon: _checking
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _resolved != null
                    ? const Icon(Icons.check_circle, color: AppColors.green)
                    : null,
          ),
        ),
        const SizedBox(height: 6),
        if (_resolved != null)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'Code appliqué — bienvenue de la part de ${_resolved!.name} !',
              style: const TextStyle(color: AppColors.green, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          )
        else if (_notFound)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text('Code non reconnu',
                style: TextStyle(color: AppColors.red, fontSize: 12)),
          )
        else
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'Vous avez reçu un code de votre école ou partenaire ?',
              style: TextStyle(color: context.textHintColor, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
