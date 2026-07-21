import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'comment_model.dart';

class CommentTile extends StatelessWidget {
  final CommentModel comment;
  final bool isOwner;
  final bool isReply;
  final VoidCallback onReply;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const CommentTile({
    super.key,
    required this.comment,
    required this.isOwner,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    this.isReply = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: isReply ? 40 : 0, top: 10, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: isReply ? 14 : 16,
            backgroundImage: comment.authorAvatarUrl != null
                ? CachedNetworkImageProvider(comment.authorAvatarUrl!)
                : null,
            child: comment.authorAvatarUrl == null ? const Icon(Icons.person, size: 14) : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(comment.authorName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      if (comment.content.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(comment.content),
                      ],
                      if (comment.imageUrls.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: comment.imageUrls
                              .map((url) => ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CachedNetworkImage(
                                      imageUrl: url,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Row(
                    children: [
                      Text(timeago.format(comment.createdAt),
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: onReply,
                        child: Text('Reply', style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                      ),
                      if (isOwner) ...[
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: onEdit,
                          child: Text('Edit', style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: onDelete,
                          child: const Text('Delete', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}