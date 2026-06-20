import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme_ext.dart';
import '../../models/verification_model.dart';
import '../../services/session_service.dart';
import '../../services/veriff_service.dart';

/// Reusable banner displayed at the top of the candidate profile.
/// Drives the user towards verification or surfaces the current status.
class VerificationStatusBanner extends ConsumerWidget {
  /// If [userId] is provided, fetches status for that user (e.g. from recruiter view).
  /// If null, fetches for the current session user.
  final String? userId;
  const VerificationStatusBanner({super.key, this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = userId ?? ref.watch(sessionProvider).userId;
    return StreamBuilder<VerificationModel?>(
      stream: ref.watch(veriffServiceProvider).statusStream(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const SizedBox.shrink();
        }
        final model = snap.data;
        final status = model?.status ?? VeriffStatus.unverified;
        return _BannerContent(status: status, declineReason: model?.declineReason);
      },
    );
  }
}

class _BannerContent extends StatelessWidget {
  final VeriffStatus status;
  final String? declineReason;
  const _BannerContent({required this.status, this.declineReason});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case VeriffStatus.unverified:
        return _Banner(
          color: context.surfaceColor,
          borderColor: context.borderColor,
          icon: Icons.shield_outlined,
          iconColor: context.textSecondaryColor,
          text: 'Vérifiez votre identité pour obtenir plus de matches',
          trailing: _CtaButton(label: 'Vérifier', onTap: () => context.push('/candidate/verification')),
        );

      case VeriffStatus.pending:
        return _Banner(
          color: const Color(0xFFFEF9C3),
          borderColor: AppColors.orange.withOpacity(0.4),
          icon: Icons.hourglass_bottom_outlined,
          iconColor: AppColors.orange,
          text: 'Vérification en cours…',
        );

      case VeriffStatus.verified:
        return _Banner(
          color: const Color(0xFFEFF6FF),
          borderColor: const Color(0xFF3B82F6).withOpacity(0.3),
          icon: Icons.verified_user,
          iconColor: const Color(0xFF3B82F6),
          text: 'Identité vérifiée',
          isBold: true,
        );

      case VeriffStatus.rejected:
        return _Banner(
          color: AppColors.redLight,
          borderColor: AppColors.red.withOpacity(0.3),
          icon: Icons.gpp_bad_outlined,
          iconColor: AppColors.red,
          text: declineReason != null
              ? 'Vérification refusée — $declineReason'
              : 'Vérification refusée',
          trailing: _CtaButton(
            label: 'Réessayer',
            onTap: () => context.push('/candidate/verification'),
            color: AppColors.red,
          ),
        );

      case VeriffStatus.resubmissionRequested:
        return _Banner(
          color: const Color(0xFFFFF7ED),
          borderColor: AppColors.orange.withOpacity(0.4),
          icon: Icons.document_scanner_outlined,
          iconColor: AppColors.orange,
          text: 'Document illisible — veuillez resoumettre',
          trailing: _CtaButton(
            label: 'Resoumettre',
            onTap: () => context.push('/candidate/verification'),
            color: AppColors.orange,
          ),
        );
    }
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final Color borderColor;
  final IconData icon;
  final Color iconColor;
  final String text;
  final Widget? trailing;
  final bool isBold;

  const _Banner({
    required this.color,
    required this.borderColor,
    required this.icon,
    required this.iconColor,
    required this.text,
    this.trailing,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: context.textPrimaryColor,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ]),
    );
  }
}

class _CtaButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _CtaButton({
    required this.label,
    required this.onTap,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
