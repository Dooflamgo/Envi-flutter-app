class PostModel {
  final String id;
  final String userId;
  final String content;
  final List<String> imageUrls;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String authorName;
  final String? authorAvatarUrl;
  final int likeCount;
  final int repostCount;
  final bool isLikedByMe;
  final bool isRepostedByMe;

  PostModel({
    required this.id,
    required this.userId,
    required this.content,
    required this.imageUrls,
    required this.createdAt,
    required this.updatedAt,
    required this.authorName,
    this.authorAvatarUrl,
    this.likeCount = 0,
    this.repostCount = 0,
    this.isLikedByMe = false,
    this.isRepostedByMe = false,
  });

  factory PostModel.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    final likeList = map['likes'] as List?;
    final repostList = map['reposts'] as List?;

    return PostModel(
      id: map['id'],
      userId: map['user_id'],
      content: map['content'] ?? '',
      imageUrls: List<String>.from(map['image_urls'] ?? []),
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      authorName: profile?['name'] ?? 'Unknown',
      authorAvatarUrl: profile?['avatar_url'],
      likeCount: likeList != null && likeList.isNotEmpty ? likeList[0]['count'] as int : 0,
      repostCount: repostList != null && repostList.isNotEmpty ? repostList[0]['count'] as int : 0,
    );
  }

  PostModel copyWith({
    int? likeCount,
    int? repostCount,
    bool? isLikedByMe,
    bool? isRepostedByMe,
  }) {
    return PostModel(
      id: id,
      userId: userId,
      content: content,
      imageUrls: imageUrls,
      createdAt: createdAt,
      updatedAt: updatedAt,
      authorName: authorName,
      authorAvatarUrl: authorAvatarUrl,
      likeCount: likeCount ?? this.likeCount,
      repostCount: repostCount ?? this.repostCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      isRepostedByMe: isRepostedByMe ?? this.isRepostedByMe,
    );
  }
}