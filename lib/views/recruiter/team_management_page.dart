import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_theme_ext.dart';
import '../../models/team.dart';
import '../../services/session_service.dart';
import '../../services/team_service.dart';
import '../../l10n/generated/app_localizations.dart';

class TeamManagementPage extends ConsumerStatefulWidget {
  const TeamManagementPage({super.key});

  @override
  ConsumerState<TeamManagementPage> createState() => _TeamManagementPageState();
}

class _TeamManagementPageState extends ConsumerState<TeamManagementPage> {
  Team? _team;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final userId = ref.read(sessionProvider).userId;
      final svc = ref.read(teamServiceProvider);
      final team = await svc.getTeamByOwner(userId) ?? await svc.getTeamByMember(userId);
      if (mounted) setState(() { _team = team; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _createTeam() async {
    setState(() => _loading = true);
    try {
      final userId = ref.read(sessionProvider).userId;
      final svc = ref.read(teamServiceProvider);
      await svc.createTeam(userId);
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')),
              backgroundColor: AppColors.red),
        );
      }
    }
  }

  Future<void> _inviteMember() async {
    final loc = AppLocalizations.of(context)!;
    final emailCtrl = TextEditingController();
    String? role = 'member';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.teamInviteTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailCtrl,
              decoration: InputDecoration(
                labelText: loc.teamMemberEmail,
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            StatefulBuilder(builder: (_, setLocal) {
              return DropdownButtonFormField<String>(
                value: role,
                items: [
                  DropdownMenuItem(value: 'member', child: Text(loc.teamRoleMember)),
                  DropdownMenuItem(value: 'admin', child: Text(loc.teamRoleAdmin)),
                ],
                onChanged: (v) { setLocal(() => role = v); },
                decoration: InputDecoration(labelText: loc.teamRole),
              );
            }),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.teamCancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(loc.teamInvite, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || _team == null) return;
    try {
      final svc = ref.read(teamServiceProvider);
      final userId = ref.read(sessionProvider).userId;
      await svc.inviteMember(
        _team!.teamId,
        userId,
        emailCtrl.text.trim(),
        role ?? 'member',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.teamInviteSent), backgroundColor: AppColors.green),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')),
              backgroundColor: AppColors.red),
        );
      }
    }
  }

  Future<void> _removeMember(String memberId, String displayName) async {
    final loc = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.teamRemoveMemberTitle),
        content: Text(loc.teamRemoveMemberBody(displayName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.teamCancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            child: Text(loc.teamRemove, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || _team == null) return;
    try {
      final svc = ref.read(teamServiceProvider);
      await svc.removeMember(_team!.teamId, memberId);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.teamTitle),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        actions: [
          if (_team != null)
            IconButton(
              icon: const Icon(Icons.person_add_outlined),
              onPressed: _inviteMember,
              tooltip: loc.teamInviteMemberTooltip,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _buildError()
              : _team == null
                  ? _buildEmpty()
                  : _buildTeam(),
    );
  }

  Widget _buildError() {
    final loc = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: AppColors.orange),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.push('/recruiter/plans'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: Text(loc.teamUpgradeToPro, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final loc = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_outlined, size: 64, color: context.textHintColor),
            const SizedBox(height: 16),
            Text(loc.teamNoTeamYet,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.textPrimaryColor)),
            const SizedBox(height: 8),
            Text(loc.teamNoTeamBody,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textSecondaryColor, height: 1.5)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _createTeam,
              icon: const Icon(Icons.group_add, color: Colors.white),
              label: Text(loc.teamCreateMyTeam, style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeam() {
    final loc = AppLocalizations.of(context)!;
    final userId = ref.read(sessionProvider).userId;
    final isOwner = _team!.isOwner(userId);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.group, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loc.teamTitle,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(loc.teamMemberCount(_team!.members.length),
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(loc.teamMembers,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: context.textPrimaryColor)),
        const SizedBox(height: 12),
        ..._team!.members.map((m) {
          final isMe = m.userId == userId;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.borderColor),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primaryLight,
                  backgroundImage: m.photoUrl != null ? CachedNetworkImageProvider(m.photoUrl!) : null,
                  child: m.photoUrl == null
                      ? Text(
                          (m.displayName?.isNotEmpty == true) ? m.displayName![0].toUpperCase() : '?',
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(
                          (m.displayName?.isNotEmpty == true) ? m.displayName! : (m.email ?? m.userId),
                          style: TextStyle(fontWeight: FontWeight.w600, color: context.textPrimaryColor),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(loc.teamYou,
                                style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ]),
                      Text(m.roleEnum.label,
                          style: TextStyle(fontSize: 12, color: context.textSecondaryColor)),
                    ],
                  ),
                ),
                if (isOwner && !isMe)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: AppColors.red, size: 20),
                    onPressed: () => _removeMember(m.userId, m.displayName ?? m.email ?? m.userId),
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _inviteMember,
          icon: const Icon(Icons.person_add_outlined, color: AppColors.primary),
          label: Text(loc.teamInviteCollaborator, style: const TextStyle(color: AppColors.primary)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.primary),
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      ],
    );
  }
}
