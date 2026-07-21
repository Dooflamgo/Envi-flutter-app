class PostModel {
  final String id;
  final String userId;
  final String content;
  final List<String> imageUrls;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String authorName;
  final String? authorAvatarUrl;

  PostModel({
    required this.id,
    required this.userId,
    required this.content,
    required this.imageUrls,
    required this.createdAt,
    required this.updatedAt,
    required this.authorName,
    this.authorAvatarUrl,
  });

  factory PostModel.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    return PostModel(
      id: map['id'],
      userId: map['user_id'],
      content: map['content'] ?? '',
      imageUrls: List<String>.from(map['image_urls'] ?? []),
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      authorName: profile?['name'] ?? 'Unknown',
      authorAvatarUrl: profile?['avatar_url'],
    );
  }
}