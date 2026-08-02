class NotificationModel {
  final String id;
  final String type;
  final String actorId;
  final String actorName;
  final String? actorAvatarUrl;
  final String? postId;
  final String? commentId;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.type,
    required this.actorId,
    required this.actorName,
    this.actorAvatarUrl,
    this.postId,
    this.commentId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    return NotificationModel(
      id: map['id'],
      type: map['type'],
      actorId: map['actor_id'],
      actorName: profile?['name'] ?? 'Someone',
      actorAvatarUrl: profile?['avatar_url'],
      postId: map['post_id'],
      commentId: map['comment_id'],
      isRead: map['is_read'] ?? false,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
        id: id, type: type, actorId: actorId, actorName: actorName,
        actorAvatarUrl: actorAvatarUrl, postId: postId, commentId: commentId,
        isRead: isRead ?? this.isRead, createdAt: createdAt,
      );

  String get message {
    switch (type) {
      case 'like': return '$actorName liked your post';
      case 'comment': return '$actorName commented on your post';
      case 'reply': return '$actorName replied to your comment';
      case 'repost': return '$actorName reposted your post';
      case 'new_post': return '$actorName created a new post';
      case 'follow': return '$actorName started following you';
      default: return '$actorName interacted with your content';
    }
  }
}