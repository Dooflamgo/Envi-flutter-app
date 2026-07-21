import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../auth/auth_provider.dart';
import 'post_provider.dart';
import 'post_model.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  PostModel? _post;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final post = await context.read<PostProvider>().fetchSinglePost(widget.postId);
    setState(() {
      _post = post;
      _isLoading = false;
    });
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => context.pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<PostProvider>().deletePost(_post!.id, _post!.userId);
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().userId;
    final isOwner = _post != null && _post!.userId == userId;

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
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmDelete,
            ),
          ],
        ],
      ),
      body: _isLoading || _post == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  Text('Comments', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text('Comments coming in the next step', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
    );
  }
}