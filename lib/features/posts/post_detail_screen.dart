import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../auth/auth_provider.dart';
import 'post_provider.dart';
import 'post_model.dart';
import '../comments/comment_provider.dart';
import '../comments/comment_model.dart';
import '../comments/comment_tile.dart';
import '../comments/comment_composer.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  PostModel? _post;
  bool _isLoading = true;
  CommentModel? _replyingTo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final post = await context.read<PostProvider>().fetchSinglePost(widget.postId);
    if (!mounted) return;
    setState(() {
      _post = post;
      _isLoading = false;
    });
    await context.read<CommentProvider>().fetchComments(widget.postId);
  }

  Future<void> _confirmDeletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => context.pop(true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<PostProvider>().deletePost(_post!.id, _post!.userId);
      if (mounted) context.pop();
    }
  }

  Future<void> _confirmDeleteComment(CommentModel comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => context.pop(true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<CommentProvider>().deleteComment(comment.id, widget.postId, comment.userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().userId;
    final isOwner = _post != null && _post!.userId == userId;
    final commentProvider = context.watch<CommentProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        actions: [
          if (isOwner) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final updated = await context.push<bool>('/edit-post/${_post!.id}', extra: _post);
                if (updated == true) _load();
              },
            ),
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _confirmDeletePost),
          ],
        ],
      ),
      body: _isLoading || _post == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: _post!.authorAvatarUrl != null
                                ? CachedNetworkImageProvider(_post!.authorAvatarUrl!)
                                : null,
                            child: _post!.authorAvatarUrl == null ? const Icon(Icons.person) : null,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_post!.authorName, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(timeago.format(_post!.createdAt), style: TextStyle(color: Colors.grey.shade600)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(_post!.content, style: const TextStyle(fontSize: 16)),
                      if (_post!.imageUrls.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        ..._post!.imageUrls.map((url) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, width: double.infinity),
                              ),
                            )),
                      ],
                      const Divider(height: 32),
                      Text('Comments (${commentProvider.comments.length})',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (commentProvider.isLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (commentProvider.topLevel().isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text('No comments yet — be the first!', style: TextStyle(color: Colors.grey.shade600)),
                        )
                      else
                        ...commentProvider.topLevel().expand((c) => [
                              CommentTile(
                                comment: c,
                                isOwner: c.userId == userId,
                                onReply: () => setState(() => _replyingTo = c),
                                onEdit: () => _openEditComment(c),
                                onDelete: () => _confirmDeleteComment(c),
                              ),
                              ...commentProvider.repliesTo(c.id).map((r) => CommentTile(
                                    comment: r,
                                    isOwner: r.userId == userId,
                                    isReply: true,
                                    onReply: () => setState(() => _replyingTo = c), // replies nest one level deep
                                    onEdit: () => _openEditComment(r),
                                    onDelete: () => _confirmDeleteComment(r),
                                  )),
                            ]),
                    ],
                  ),
                ),
                if (userId != null)
                  Container(
                    padding: EdgeInsets.only(
                      left: 12, right: 12, top: 8,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey.shade300)),
                    ),
                    child: CommentComposer(
                      replyingToName: _replyingTo?.authorName,
                      onCancelReply: () => setState(() => _replyingTo = null),
                      onSubmit: (content, images) async {
                        await context.read<CommentProvider>().addComment(
                              postId: widget.postId,
                              userId: userId,
                              content: content,
                              parentCommentId: _replyingTo?.id,
                              images: images,
                            );
                        setState(() => _replyingTo = null);
                      },
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextButton(
                      onPressed: () => context.push('/login'),
                      child: const Text('Log in to comment'),
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _openEditComment(CommentModel comment) async {
    final updated = await context.push<bool>('/edit-comment', extra: comment);
    if (updated == true) {
      context.read<CommentProvider>().fetchComments(widget.postId);
    }
  }
}