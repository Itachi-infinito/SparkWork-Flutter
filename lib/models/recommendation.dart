class Recommendation {
  final String recommendationId;
  final String authorName;
  final String authorRole;
  final String authorCompany;
  final String candidateId;
  final String text;
  final bool isPublished; // approuvé par le candidat
  final String status;    // pending / approved / rejected
  final String createdAt;
  final String? linkToken; // token unique pour le formulaire

  const Recommendation({
    required this.recommendationId,
    required this.authorName,
    required this.authorRole,
    required this.authorCompany,
    required this.candidateId,
    required this.text,
    this.isPublished = false,
    this.status = 'pending',
    required this.createdAt,
    this.linkToken,
  });

  Map<String, dynamic> toMap() => {
        'recommendationId': recommendationId,
        'authorName': authorName,
        'authorRole': authorRole,
        'authorCompany': authorCompany,
        'candidateId': candidateId,
        'text': text,
        'isPublished': isPublished,
        'status': status,
        'createdAt': createdAt,
        if (linkToken != null) 'linkToken': linkToken,
      };

  factory Recommendation.fromMap(Map<String, dynamic> map) => Recommendation(
        recommendationId: map['recommendationId'] as String? ?? '',
        authorName: map['authorName'] as String? ?? '',
        authorRole: map['authorRole'] as String? ?? '',
        authorCompany: map['authorCompany'] as String? ?? '',
        candidateId: map['candidateId'] as String? ?? '',
        text: map['text'] as String? ?? '',
        isPublished: map['isPublished'] as bool? ?? false,
        status: map['status'] as String? ?? 'pending',
        createdAt: map['createdAt'] as String? ?? '',
        linkToken: map['linkToken'] as String?,
      );
}
