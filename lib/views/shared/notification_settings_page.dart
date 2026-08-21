import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme_ext.dart';
import '../../models/notification_preferences.dart';
import '../../services/notification_preferences_service.dart';
import '../../services/session_service.dart';
import '../../l10n/generated/app_localizations.dart';

class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends ConsumerState<NotificationSettingsPage> {
  NotificationPreferences? _prefs;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = ref.read(sessionProvider).userId;
    final svc = ref.read(notificationPreferencesServiceProvider);
    final prefs = await svc.getPreferences(userId);
    if (mounted) setState(() { _prefs = prefs; _loading = false; });
  }

  Future<void> _save() async {
    if (_prefs == null) return;
    final loc = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    try {
      final svc = ref.read(notificationPreferencesServiceProvider);
      await svc.savePreferences(_prefs!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.notifSettingsSaved), backgroundColor: AppColors.green),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggle(String key, bool value) {
    if (_prefs == null) return;
    setState(() {
      _prefs = _prefs!.copyWith(
        matchReminder: key == 'matchReminder' ? value : null,
        newProfilesForRecruiter: key == 'newProfilesForRecruiter' ? value : null,
        noSwipeReminderCandidate: key == 'noSwipeReminderCandidate' ? value : null,
        swipeRechargeAlert: key == 'swipeRechargeAlert' ? value : null,
        trialExpiryReminder: key == 'trialExpiryReminder' ? value : null,
        noMatchOfferSuggestion: key == 'noMatchOfferSuggestion' ? value : null,
        flashOfferNearby: key == 'flashOfferNearby' ? value : null,
        availableNowExpiry: key == 'availableNowExpiry' ? value : null,
        verificationUpdate: key == 'verificationUpdate' ? value : null,
        ratingReminder: key == 'ratingReminder' ? value : null,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.notifSettingsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(loc.notifSettingsSave,
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _prefs == null
              ? Center(child: Text(loc.notifSettingsLoadError))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final loc = AppLocalizations.of(context)!;
    final p = _prefs!;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionHeader(loc.notifSettingsSectionActivity),
        _ToggleTile(
          icon: Icons.favorite_border,
          title: loc.notifSettingsMatchTitle,
          subtitle: loc.notifSettingsMatchSubtitle,
          value: p.matchReminder,
          onChanged: (v) => _toggle('matchReminder', v),
        ),
        _ToggleTile(
          icon: Icons.person_search_outlined,
          title: loc.notifSettingsNewProfilesTitle,
          subtitle: loc.notifSettingsNewProfilesSubtitle,
          value: p.newProfilesForRecruiter,
          onChanged: (v) => _toggle('newProfilesForRecruiter', v),
        ),
        _ToggleTile(
          icon: Icons.swipe_outlined,
          title: loc.notifSettingsSwipeReminderTitle,
          subtitle: loc.notifSettingsSwipeReminderSubtitle,
          value: p.noSwipeReminderCandidate,
          onChanged: (v) => _toggle('noSwipeReminderCandidate', v),
        ),
        _ToggleTile(
          icon: Icons.refresh,
          title: loc.notifSettingsSwipeRechargeTitle,
          subtitle: loc.notifSettingsSwipeRechargeSubtitle,
          value: p.swipeRechargeAlert,
          onChanged: (v) => _toggle('swipeRechargeAlert', v),
        ),
        const SizedBox(height: 20),
        _SectionHeader(loc.notifSettingsSectionAccount),
        _ToggleTile(
          icon: Icons.access_time_outlined,
          title: loc.notifSettingsTrialExpiryTitle,
          subtitle: loc.notifSettingsTrialExpirySubtitle,
          value: p.trialExpiryReminder,
          onChanged: (v) => _toggle('trialExpiryReminder', v),
        ),
        _ToggleTile(
          icon: Icons.verified_outlined,
          title: loc.notifSettingsVerificationTitle,
          subtitle: loc.notifSettingsVerificationSubtitle,
          value: p.verificationUpdate,
          onChanged: (v) => _toggle('verificationUpdate', v),
        ),
        const SizedBox(height: 20),
        _SectionHeader(loc.notifSettingsSectionOffers),
        _ToggleTile(
          icon: Icons.bolt,
          title: loc.notifSettingsFlashTitle,
          subtitle: loc.notifSettingsFlashSubtitle,
          value: p.flashOfferNearby,
          onChanged: (v) => _toggle('flashOfferNearby', v),
        ),
        _ToggleTile(
          icon: Icons.work_off_outlined,
          title: loc.notifSettingsSuggestionsTitle,
          subtitle: loc.notifSettingsSuggestionsSubtitle,
          value: p.noMatchOfferSuggestion,
          onChanged: (v) => _toggle('noMatchOfferSuggestion', v),
        ),
        const SizedBox(height: 20),
        _SectionHeader(loc.notifSettingsSectionAvailability),
        _ToggleTile(
          icon: Icons.schedule_outlined,
          title: loc.notifSettingsAvailNowTitle,
          subtitle: loc.notifSettingsAvailNowSubtitle,
          value: p.availableNowExpiry,
          onChanged: (v) => _toggle('availableNowExpiry', v),
        ),
        _ToggleTile(
          icon: Icons.star_outline,
          title: loc.notifSettingsRatingReminderTitle,
          subtitle: loc.notifSettingsRatingReminderSubtitle,
          value: p.ratingReminder,
          onChanged: (v) => _toggle('ratingReminder', v),
        ),
        const SizedBox(height: 20),
        _SectionHeader(loc.notifSettingsSectionQuietHours),
        _QuietHoursRow(
          start: p.quietHourStart,
          end: p.quietHourEnd,
          onStartChanged: (v) => setState(() => _prefs = _prefs!.copyWith(quietHourStart: v)),
          onEndChanged: (v) => setState(() => _prefs = _prefs!.copyWith(quietHourEnd: v)),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: context.textSecondaryColor,
              letterSpacing: 0.5)),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: SwitchListTile(
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: value ? AppColors.primaryLight : context.borderColor.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              size: 18, color: value ? AppColors.primary : context.textSecondaryColor),
        ),
        title: Text(title,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.textPrimaryColor)),
        subtitle: Text(subtitle,
            style: TextStyle(fontSize: 12, color: context.textSecondaryColor)),
        value: value,
        activeColor: AppColors.primary,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }
}

class _QuietHoursRow extends StatelessWidget {
  final int start;
  final int end;
  final ValueChanged<int> onStartChanged;
  final ValueChanged<int> onEndChanged;
  const _QuietHoursRow({
    required this.start,
    required this.end,
    required this.onStartChanged,
    required this.onEndChanged,
  });

  String _fmt(int h) => '${h.toString().padLeft(2, '0')}:00';

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.bedtime_outlined, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(loc.notifSettingsQuietHoursSummary(_fmt(start), _fmt(end)),
                style: TextStyle(fontSize: 13, color: context.textPrimaryColor)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loc.notifSettingsQuietStart, style: TextStyle(fontSize: 11, color: context.textSecondaryColor)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<int>(
                    value: start,
                    isDense: true,
                    items: List.generate(24, (i) => DropdownMenuItem(value: i, child: Text(_fmt(i)))),
                    onChanged: (v) { if (v != null) onStartChanged(v); },
                    decoration: const InputDecoration(isDense: true),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loc.notifSettingsQuietEnd, style: TextStyle(fontSize: 11, color: context.textSecondaryColor)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<int>(
                    value: end,
                    isDense: true,
                    items: List.generate(24, (i) => DropdownMenuItem(value: i, child: Text(_fmt(i)))),
                    onChanged: (v) { if (v != null) onEndChanged(v); },
                    decoration: const InputDecoration(isDense: true),
                  ),
                ],
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
