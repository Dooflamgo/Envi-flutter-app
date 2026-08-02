class CommentModel {
  final String id;
  final String postId;
  final String userId;
  final String? parentCommentId;
  final String content;
  final List<String> imageUrls;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String authorName;
  final String? authorAvatarUrl;

  CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    this.parentCommentId,
    required this.content,
    required this.imageUrls,
    required this.createdAt,
    required this.updatedAt,
    required this.authorName,
    this.authorAvatarUrl,
  });

  factory CommentModel.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    return CommentModel(
      id: map['id'],
      postId: map['post_id'],
      userId: map['user_id'],
      parentCommentId: map['parent_comment_id'],
      content: map['content'] ?? '',
      imageUrls: List<String>.from(map['image_urls'] ?? []),
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      authorName: profile?['name'] ?? 'Unknown',
      authorAvatarUrl: profile?['avatar_url'],
    );
  }
}