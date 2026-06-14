enum TeamMemberRole { owner, admin, member }

extension TeamMemberRoleExt on TeamMemberRole {
  String get label {
    switch (this) {
      case TeamMemberRole.owner: return 'Propriétaire';
      case TeamMemberRole.admin: return 'Administrateur';
      case TeamMemberRole.member: return 'Membre';
    }
  }

  String get name {
    switch (this) {
      case TeamMemberRole.owner: return 'owner';
      case TeamMemberRole.admin: return 'admin';
      case TeamMemberRole.member: return 'member';
    }
  }
}

class TeamMember {
  final String userId;
  final String role; // owner / admin / member
  final String joinedAt;
  final String? invitedBy;
  final String? displayName;
  final String? email;
  final String? photoUrl;

  const TeamMember({
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.invitedBy,
    this.displayName,
    this.email,
    this.photoUrl,
  });

  TeamMemberRole get roleEnum {
    switch (role) {
      case 'owner': return TeamMemberRole.owner;
      case 'admin': return TeamMemberRole.admin;
      default: return TeamMemberRole.member;
    }
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'role': role,
        'joinedAt': joinedAt,
        if (invitedBy != null) 'invitedBy': invitedBy,
        if (displayName != null) 'displayName': displayName,
        if (email != null) 'email': email,
        if (photoUrl != null) 'photoUrl': photoUrl,
      };

  factory TeamMember.fromMap(Map<String, dynamic> map) => TeamMember(
        userId: map['userId'] as String? ?? '',
        role: map['role'] as String? ?? 'member',
        joinedAt: map['joinedAt'] as String? ?? '',
        invitedBy: map['invitedBy'] as String?,
        displayName: map['displayName'] as String?,
        email: map['email'] as String?,
        photoUrl: map['photoUrl'] as String?,
      );
}

class Team {
  final String teamId;
  final String companyId; // userId du propriétaire
  final List<TeamMember> members;
  final String createdAt;

  const Team({
    required this.teamId,
    required this.companyId,
    required this.members,
    required this.createdAt,
  });

  bool isMember(String userId) => members.any((m) => m.userId == userId);
  bool isOwner(String userId) => members.any((m) => m.userId == userId && m.role == 'owner');
  bool isAdmin(String userId) => members.any((m) => m.userId == userId && (m.role == 'owner' || m.role == 'admin'));

  Map<String, dynamic> toMap() => {
        'teamId': teamId,
        'companyId': companyId,
        'members': members.map((m) => m.toMap()).toList(),
        'createdAt': createdAt,
      };

  factory Team.fromMap(Map<String, dynamic> map) => Team(
        teamId: map['teamId'] as String? ?? '',
        companyId: map['companyId'] as String? ?? '',
        members: (map['members'] as List<dynamic>? ?? [])
            .map((m) => TeamMember.fromMap(m as Map<String, dynamic>))
            .toList(),
        createdAt: map['createdAt'] as String? ?? '',
      );
}

enum SwipeVoteType { pass, retain, favorite }

extension SwipeVoteTypeExt on SwipeVoteType {
  String get label {
    switch (this) {
      case SwipeVoteType.pass: return 'Passer';
      case SwipeVoteType.retain: return 'Retenir';
      case SwipeVoteType.favorite: return 'Favori';
    }
  }

  String get value {
    switch (this) {
      case SwipeVoteType.pass: return 'pass';
      case SwipeVoteType.retain: return 'retain';
      case SwipeVoteType.favorite: return 'favorite';
    }
  }
}

class SwipeVote {
  final String voteId;
  final String teamId;
  final String offerId;
  final String candidateId;
  final String voterId;
  final String vote; // pass / retain / favorite
  final String? note; // note interne visible par l'équipe uniquement
  final String createdAt;
  final String? voterName;
  final String? voterPhotoUrl;

  const SwipeVote({
    required this.voteId,
    required this.teamId,
    required this.offerId,
    required this.candidateId,
    required this.voterId,
    required this.vote,
    this.note,
    required this.createdAt,
    this.voterName,
    this.voterPhotoUrl,
  });

  SwipeVoteType get voteEnum {
    switch (vote) {
      case 'retain': return SwipeVoteType.retain;
      case 'favorite': return SwipeVoteType.favorite;
      default: return SwipeVoteType.pass;
    }
  }

  Map<String, dynamic> toMap() => {
        'voteId': voteId,
        'teamId': teamId,
        'offerId': offerId,
        'candidateId': candidateId,
        'voterId': voterId,
        'vote': vote,
        if (note != null) 'note': note,
        'createdAt': createdAt,
        if (voterName != null) 'voterName': voterName,
        if (voterPhotoUrl != null) 'voterPhotoUrl': voterPhotoUrl,
      };

  factory SwipeVote.fromMap(Map<String, dynamic> map) => SwipeVote(
        voteId: map['voteId'] as String? ?? '',
        teamId: map['teamId'] as String? ?? '',
        offerId: map['offerId'] as String? ?? '',
        candidateId: map['candidateId'] as String? ?? '',
        voterId: map['voterId'] as String? ?? '',
        vote: map['vote'] as String? ?? 'pass',
        note: map['note'] as String?,
        createdAt: map['createdAt'] as String? ?? '',
        voterName: map['voterName'] as String?,
        voterPhotoUrl: map['voterPhotoUrl'] as String?,
      );
}
